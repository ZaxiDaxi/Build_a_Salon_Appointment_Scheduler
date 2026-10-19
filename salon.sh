#! /bin/bash

# Read SQL from stdin so psql can safely quote input variables.
PSQL=(psql --username=freecodecamp --dbname=salon -X -t -A -q -v ON_ERROR_STOP=1)

printf '\n~~~~~ THE SALON ~~~~~\n\nWelcome! Which service would you like?\n'

while true; do
  "${PSQL[@]}" -c "SELECT service_id || ') ' || name FROM services ORDER BY service_id;" || exit 1
  IFS= read SERVICE_ID_SELECTED || exit 0

  SERVICE_NAME=$("${PSQL[@]}" -v service_id="$SERVICE_ID_SELECTED" <<'SQL'
SELECT name FROM services WHERE service_id::text = :'service_id';
SQL
  ) || exit 1

  if [[ -n $SERVICE_NAME ]]; then
    break
  fi
  printf '\nI could not find that service. Please choose from this list:\n'
done

printf '\nWhat is your phone number?\n'
IFS= read CUSTOMER_PHONE || exit 0

CUSTOMER_ID=$("${PSQL[@]}" -v phone="$CUSTOMER_PHONE" <<'SQL'
SELECT customer_id FROM customers WHERE phone = :'phone';
SQL
) || exit 1

if [[ -z $CUSTOMER_ID ]]; then
  printf '\nYou are a new customer. What is your name?\n'
  IFS= read CUSTOMER_NAME || exit 0
  CUSTOMER_ID=$("${PSQL[@]}" -v phone="$CUSTOMER_PHONE" -v name="$CUSTOMER_NAME" <<'SQL'
INSERT INTO customers (phone, name) VALUES (:'phone', :'name') RETURNING customer_id;
SQL
  ) || exit 1
else
  CUSTOMER_NAME=$("${PSQL[@]}" -v customer_id="$CUSTOMER_ID" <<'SQL'
SELECT name FROM customers WHERE customer_id = :'customer_id'::integer;
SQL
  ) || exit 1
fi

printf '\nWhat time would you like your %s, %s?\n' "$SERVICE_NAME" "$CUSTOMER_NAME"
IFS= read SERVICE_TIME || exit 0

"${PSQL[@]}" -v customer_id="$CUSTOMER_ID" -v service_id="$SERVICE_ID_SELECTED" -v time="$SERVICE_TIME" <<'SQL'
INSERT INTO appointments (customer_id, service_id, time)
VALUES (:'customer_id'::integer, :'service_id'::integer, :'time');
SQL
if [[ $? -ne 0 ]]; then
  exit 1
fi

printf '\nI have put you down for a %s at %s, %s.\n' "$SERVICE_NAME" "$SERVICE_TIME" "$CUSTOMER_NAME"
