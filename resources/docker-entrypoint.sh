#!/bin/bash

echo "Configure server.xml (proxy and context root)"
if [ "$(stat --format "%Y" "${JIRA_INSTALL}/conf/server.xml")" -eq "0" ]; then

  if [ -n "${ADOP_PROXYNAME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "proxyName" --value "${ADOP_PROXYNAME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${ADOP_PROXYPORT}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "proxyPort" --value "${ADOP_PROXYPORT}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${ADOP_PROXYSCHEME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "scheme" --value "${ADOP_PROXYSCHEME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${JIRA_ROOTPATH}" ]; then
    xmlstarlet ed --inplace --pf --ps --update '//Context/@path' --value "${JIRA_ROOTPATH}" "${JIRA_INSTALL}/conf/server.xml"
  fi

fi

echo "Init dbconfig.xml (database)"
# If configuration is present
if [[ -n "${DB_HOST}" && -n "${JIRA_DB}" && -n "${JIRA_DB_USER}" && -n "${JIRA_DB_PASSWORD}" ]];then
	# At the first launch
	if [ ! -f "${JIRA_HOME}/dbconfig.xml" ]; then
		mv "${JIRA_HOME}/dbconfig.xml.template" "${JIRA_HOME}/dbconfig.xml"
	fi
	# Update values
	xmlstarlet ed --inplace -u "/jira-database-config/jdbc-datasource/url" --value "jdbc:postgresql://${DB_HOST}:5432/${JIRA_DB}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed --inplace -u "/jira-database-config/jdbc-datasource/username" --value "${JIRA_DB_USER}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed --inplace -u "/jira-database-config/jdbc-datasource/password" --value "${JIRA_DB_PASSWORD}" "${JIRA_HOME}/dbconfig.xml"
	
fi

echo "Checking Postgres availability ..."
until databasesList=$(PGPASSWORD="${DB_POSTGRES_PASSWORD}" psql -h "${DB_HOST}" -p "5432" -U "postgres"  -c '\l'); do
  echo "Postgres is unavailable - sleeping 1s ..."
  sleep 1
done

echo "Postgres is up !"

echo $databasesList | grep -q "${JIRA_DB}"
if [ $? -eq 0 ];then
	echo "Database ${JIRA_DB} already exists."
else
	echo "Create database ${JIRA_DB} ..."
PGPASSWORD="${DB_POSTGRES_PASSWORD}" psql -v ON_ERROR_STOP=1 --username "postgres" --host "${DB_HOST}" --port "5432" <<-EOSQL
    CREATE USER ${JIRA_DB_USER} WITH PASSWORD '${JIRA_DB_PASSWORD}';
    CREATE DATABASE ${JIRA_DB};
    GRANT ALL PRIVILEGES ON DATABASE ${JIRA_DB} TO ${JIRA_DB_USER};
EOSQL
	echo "Database ${JIRA_DB} successfully created."
fi

echo "Configuration and database setup completed successfully, starting Jira Software ..."
	
# With exec, the child process replaces the parent process entirely
# exec is more precise/correct/efficient
exec $@
