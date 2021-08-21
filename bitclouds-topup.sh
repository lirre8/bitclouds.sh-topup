#!/bin/bash

LIGHTNING_CLI="lightning-cli"
LNCLI="lncli"
PRINT_TIME=false
POSITIONAL=()
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    --amount|-a)
      AMOUNT="$2"
      shift # past argument
      shift # past value
      ;;
    --host|-h)
      HOST="$2"
      shift # past argument
      shift # past value
      ;;
    --lightning-cli)
      LIGHTNING_CLI="$2"
      shift # past argument
      shift # past value
      ;;
    --lncli)
      LNCLI="$2"
      shift # past argument
      shift # past value
      ;;
    --max-balance|-m)
      MAX_BALANCE="$2"
      shift # past argument
      shift # past value
      ;;
    --print-time|-t)
      PRINT_TIME=true
      shift # past argument
      ;;
    --wallet|-w)
      WALLET="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if $PRINT_TIME; then
  echo "Script starting at `date '+%Y-%m-%d %H:%M:%S'`"
fi

if [ -z "$HOST" ]; then
  >&2 echo "ERROR: Missing argument '--host'"
  exit 1
fi

if [ -z "$AMOUNT" ]; then
  >&2 echo "ERROR: Missing argument '--amount'"
  exit 1
fi

if [ -z "$WALLET" ]; then
  >&2 echo "ERROR: Missing argument '--wallet'"
  exit 1
fi

if ! [[ "$AMOUNT" =~ ^[0-9]+$ ]]; then
  >&2 echo "ERROR: Invalid amount '$AMOUNT' (integers only)"
  exit 1
fi

if [ -n "$MAX_BALANCE" ] && ! [[ "$MAX_BALANCE" =~ ^[0-9]+$ ]]; then
  >&2 echo "ERROR: Invalid max-balance '$MAX_BALANCE' (integers only)"
  exit 1
fi

if ! [[ "$WALLET" =~ ^(lnd|c-lightning)$ ]]; then
  >&2 echo "ERROR: Invalid wallet '$WALLET' (supported wallets are [lnd, c-lightning])"
  exit 1
fi

# Test if wallet is running
case "$WALLET" in
  "lnd")
    $LNCLI getinfo > /dev/null 2>&1
    ;;
  "c-lightning")
    $LIGHTNING_CLI getinfo > /dev/null 2>&1
    ;;
esac
if [ $? -ne 0 ]; then
  >&2 echo "ERROR: $WALLET not running?"
  exit 1
fi

if [ -n "$MAX_BALANCE" ]; then
  current_balance=$(curl -s "https://bitclouds.sh/status/$HOST" | jq -r '.balance')
  if ! [[ "$current_balance" =~ ^[0-9]+$ ]]; then
    >&2 echo "ERROR: Failed to get current balance (is jq installed?)"
    exit 1
  fi
  if [ "$current_balance" -gt "$MAX_BALANCE" ]; then
    echo "Current balance ($current_balance) is bigger than max-balance ($MAX_BALANCE)"
    exit 0
  fi
  sleep 1 # Bitclouds server responds with HTTP status 500 if the topup call is made too fast
fi

invoice=$(curl -s "https://bitclouds.sh/topup/$HOST/$AMOUNT" | jq -r '.invoice')

if [ "$invoice" == "null" ]; then
  >&2 echo "ERROR: Failed to get invoice (invalid host?)"
  exit 1
fi

case "$WALLET" in
  "lnd")
    invoice_amount=$($LNCLI decodepayreq "$invoice" | jq -r '.num_satoshis')
    ;;
  "c-lightning")
    invoice_amount=$($LIGHTNING_CLI decodepay "$invoice" | jq -r '.msatoshi' | sed 's/000$//')
    ;;
esac

if ! [[ "$invoice_amount" =~ ^[0-9]+$ ]]; then
  >&2 echo "ERROR: Failed to decode invoice '$invoice'"
  exit 1
fi

if [ "$invoice_amount" -ne "$AMOUNT" ]; then
  >&2 echo "ERROR: Failed to verify amount in invoice '$invoice'"
  exit 1
fi

echo "Paying $AMOUNT sats using $WALLET:"

case "$WALLET" in
  "lnd")
    $LNCLI payinvoice --force "$invoice"
    ;;
  "c-lightning")
    $LIGHTNING_CLI pay "$invoice" 
    ;;
esac

new_balance=$(curl -s "https://bitclouds.sh/status/$HOST" | jq -r '.balance')

echo "New balance: $new_balance"

