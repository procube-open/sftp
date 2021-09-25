# SFTP サーバ

以下の仕様の sftp サーバを提供する。

- パラメータはすべて環境変数から指定する
- データを保持するディレクトリ(以降、データディレクトリ)をマウントして動作する
- データディレクトリに chroot することで、 sftp のユーザからは、データディレクトリの外のコンテナ内のファイルは全く見えないようにする
- 1ユーザのみ登録できる
- sftp のユーザのホームディレクトリは chroot 後の / 直下となり、そのディレクトリ名を指定できる
- コンテナのサービス提供ポート番号は22である

# 環境変数

|環境変数|仕様|デフォルト値|
----|----|----
|MOUNT_POINT|データディレクトリのマウントポイント。オーナは root でなければならない|/home|
|USER_DIR_NAME|ユーザディレクトリの名前。 sftp のログインの初期ディレクトリは /$USER_DIR_NAME となる|uploader|
|USER_NAME|ユーザ名。alpine linux コンテナにデフォルトで存在するユーザ名は使用できない。|uploader|
|USER_UID|ユーザのUID。alpine linux コンテナにデフォルトで存在する UID は使用できない。|1000|
|USER_PASSWORD_HASH|ユーザのパスワードのハッシュ値。|*|
|USER_AUTHORIZED_KEYS|ユーザの公開鍵。|なし|
|GROUP_NAME|ユーザのグループ名。alpine linux コンテナにデフォルトで存在するグループ名は使用できない。|uploader|
|GROUP_GID|グループの GID。alpine linux コンテナにデフォルトで存在する GID は使用できない。|1000|
|HOST_RSA_PRIVATE_KEY|sshd が使用するRSA秘密鍵。指定した場合公開鍵は秘密鍵から抽出する。|起動時に生成した鍵|
|DENIED_OPERATIONS|SFTPサーバで禁止された操作(sftp-server の -Pオプションに渡される)|なし|
|DEBUG|1以上の数値を指定すると詳細なログを出力する。|0|

## パスワードのハッシュ値について
USER_PASSWORD_HASH 環境変数に設定するハッシュ値は Linux 環境でopenssl コマンドで取得してください。
例えば、パスワードが "Secret!_123" である場合、以下のように openssl コマンドを実行してください。

```
openssl passwd -6 -salt $(openssl rand -base64 6) 'Secret!_123'
```

上記で -6 オプション(SHA512)がサポートされていない場合は、 -1 オプション(MD5)を利用することができます。

# sshd_config

## デフォルト値からの変更
sshd_config でデフォルト（デフォルトの設定ファイルで設定されているものを含む）から変更しているものは以下の通り。

|項目|値|設定前値|仕様|
----|----|----|----
|PermitRootLogin|no|prohibit-password|root ユーザのログインを禁止|
|PasswordAuthentication|起動時設定|yes|$USER_PASSWORDが'*'以外の場合はyes、そうでなければ no|
|ChallengeResponseAuthentication|起動時設定|yes|$USER_PASSWORDが'*'以外の場合はyes、そうでなければ no|
|PubkeyAuthentication|起動時設定|yes|$USER_AUTHORIZED_KEYSが設定されている場合はyes、そうでなければ no|
|LogLevel|起動時設定|INFO|$DEBUGが設定されていて0以外の場合はVERBOSEに設定|
|ChrootDirectory|起動時設定|-|${MOUNT_POINT:-/home} を設定|
|Subsystem sftp|internal-sftp|/usr/lib/ssh/sftp-server|chroot 後も利用できる internal-sftp を使用|
|ForceCommand |internal-sftp -e|-|$DENIED_OPERATIONS が設定されている場合は、-P $DENIED_OPERATIONS を追加、$DEBUGが設定されていて0以外の場合 -l VERBOSE を追加|

## Match の使用について

sftp サーバとしてのみ動作するので、 Match によるログインユーザのグループに依存した設定上書きは行わない。

## $DENIED_OPERATIONS について

internal-sftp では -P オプションで操作を制限することができる。
例えば、$DENIED_OPERATIONS に read,remove と設定することで書き込みのみを行うことができるバックアップファイルサーバのような動作をさせることができる。

## default 値

default 値の確認のため、上書き前の、すなわち openssh openssh-sftp-server インストール直後の sshd_config を以下に示す。

```
#	$OpenBSD: sshd_config,v 1.103 2018/04/09 20:41:22 tj Exp $

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/bin:/usr/bin:/sbin:/usr/sbin

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

#Port 22
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
#PermitRootLogin prohibit-password
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

#PubkeyAuthentication yes

# The default is to check both .ssh/authorized_keys and .ssh/authorized_keys2
# but this is overridden so installations will only check .ssh/authorized_keys
AuthorizedKeysFile	.ssh/authorized_keys

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
#PasswordAuthentication yes
#PermitEmptyPasswords no

# Change to no to disable s/key passwords
#ChallengeResponseAuthentication yes

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the ChallengeResponseAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via ChallengeResponseAuthentication may bypass
# the setting of "PermitRootLogin without-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and ChallengeResponseAuthentication to 'no'.
#UsePAM no

#AllowAgentForwarding yes
# Feel free to re-enable these if your use case requires them.
AllowTcpForwarding no
GatewayPorts no
X11Forwarding no
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
#PrintMotd yes
#PrintLastLog yes
#TCPKeepAlive yes
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# override default of no subsystems
Subsystem	sftp	/usr/lib/ssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#	X11Forwarding no
#	AllowTcpForwarding no
#	PermitTTY no
#	ForceCommand cvs server
```