#!/usr/bin/expect
set timeout 20
set name [lindex $argv 0]
set user [lindex $argv 1]
set password [lindex $argv 2]
log_user 0

spawn telnet $name

expect -regexp {login:|Username:}
send "$user\n"

expect "Password:"
send "$password\n"

interact
