#!/usr/bin/env sh

set -eo pipefail
[ "${DEBUG:-0}" -gt 0 ] && set -x

# if command starts with an option, prepend pdns_server
if [ "${1:0:1}" = '-' ]; then
 set -- /usr/sbin/sshd "$@"
fi

function setParam () {
  paramname=$1
  value=$2
  if grep -q "^$paramname " /etc/ssh/sshd_config; then
    sed -r -i "s/^[# ]*${paramname} .*\$/${paramname} ${value/\//\\/}/" /etc/ssh/sshd_config
  else
    echo "${paramname} ${value}" >> /etc/ssh/sshd_config
  fi
}


# MOUNT_POINT The mount point of the data directory. The owner must be root.
DATA_DIR=${MOUNT_POINT:-/home}
setParam ChrootDirectory "${DATA_DIR}"

# GROUP_NAME The group name of the user.
#  However, the group name that exists by default in the alpine linux container cannot be used.
# GROUP_GID The GID of the group.
#  However, the GID that exists by default in the alpine linux container cannot be used.
groupadd --gid "${GROUP_GID:-1000}" "${GROUP_NAME:-uploader}"

# USER_DIR_NAME The name of the user directory. The initial directory for sftp login is /$USER_DIR_NAME.
# USER_NAME The user name.
#  However, the user name that exists by default in the alpine linux container cannot be used.
# USER_UID The UID of the user.
#  However, the user name that exists by default in the alpine linux container cannot be used.
# USER_PASSWORD_HASH Hash value of the user's password.

useradd -c 'SFTP only user' -d "${DATA_DIR}/${USER_DIR_NAME:-uploader}" -g "${GROUP_GID:-1000}" -m \
  -p "${USER_PASSWORD_HASH:-*}" -u "${USER_UID:-1000}" "${USER_NAME:-uploader}"

if [ "${USER_PASSWORD_HASH:-*}" != "*" ]; then
  setParam PasswordAuthentication yes
  setParam ChallengeResponseAuthentication yes
fi

# USER_AUTHORIZED_KEYS Public key of the user.
if [ -n "${USER_AUTHORIZED_KEYS}" ]; then
  mkdir "${DATA_DIR}/${USER_DIR_NAME:-uploader}/.ssh"
  chmod 0700 "${DATA_DIR}/${USER_DIR_NAME:-uploader}/.ssh"
  echo "${USER_AUTHORIZED_KEYS}" > "${DATA_DIR}/${USER_DIR_NAME:-uploader}/.ssh/authorized_keys"
  setParam PubkeyAuthentication yes
fi

# HOST_RSA_PRIVATE_KEY RSA private key used by sshd. If specified, the public key is extracted from the private key.
#  If not specified, the key generated at startup is used.
if [ -n "${HOST_RSA_PRIVATE_KEY}" ]; then
  echo "${HOST_RSA_PRIVATE_KEY}" > /etc/ssh/ssh_host_rsa_key
  chmod 0600 /etc/ssh/ssh_host_rsa_key
  ssh-keygen -y -f /etc/ssh/ssh_host_rsa_key > /etc/ssh/ssh_host_rsa_key.pub
else
  ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ''
fi

SFTP_SERVER_OPTIONS="-e"
if [ "${DEBUG:-0}" -gt 0 ]; then
  setParam LogLevel VERBOSE
  SFTP_SERVER_OPTIONS="${SFTP_SERVER_OPTIONS} -l VERBOSE"
fi

# DENIED_OPERATIONS Operations forbidden by SFTP server
if [ -n "${DENIED_OPERATIONS}" ]; then
  SFTP_SERVER_OPTIONS="${SFTP_SERVER_OPTIONS} -P ${DENIED_OPERATIONS}"
fi
setParam ForceCommand "internal-sftp ${SFTP_SERVER_OPTIONS}"

exec "$@"