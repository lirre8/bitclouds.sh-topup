# bitclouds.sh-topup
Topup script for [bitclouds.sh](https://github.com/bitcoin-software/bitclouds.sh). Can be setup to automatically topup your instances using lightning network when the balance is getting low.

## Prerequisites
Currently integrated lightning wallets are lnd anc c-lightning. You need one of those installed.

### Dependencies
 - curl
 - jq

## Usage
### Options
    --amount|-a
            Sets the amount to topup your instance with

    --host|-h
            Sets the host name of the instance to topup

    --lightning-cli
            Changes the command to use for c-lightning. Defaults to 'lightning-cli'

    --lncli
            Changes the command to use for lnd. Defaults to 'lncli'

    --max-balance|-m
            Sets a max balance. If the current balance of the instance is above this value, the topup will not be executed

    --print-time|-t
            Boolean. Prints current time when the script starts executing

    --wallet|-w
            Selects which wallet to use. Must be 'lnd' or 'c-lightning'

### Examples
To simply topup an instance with 10000 sats using c-lightning

    bitclouds-topup.sh --host {host-name} --amount 10000 --wallet c-lightning

To topup an instance with 10000 sats only if current balance is below 30000 using lnd

    bitclouds-topup.sh --host {host-name} --amount 10000 --max-balance 30000 --wallet lnd

By using cron it can be setup to automatically topup your instance when the balance has gone below the minimum wanted level. For example, this cron command will run the script every day at 1am. The script will topup the instance with 10000 sats only if the current balance is below 30000 and save the output to the provided log file. Note that it can be necessary to enter the full path of the commands when using crontab on Linux

    0 1 * * * /path/to/bitclouds-topup.sh --host {host-name} --amount 10000 --max-balance 30000 --wallet lnd --lncli /path/to/lncli --print-time >> /path/to/bitclouds-topup.log 2>&1

## License

Distributed under the MIT License. See `LICENSE` for more information.
