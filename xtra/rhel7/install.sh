#debug
if [ "$1" == "-d" ]; then
   shift
   set -x
   trap read debug
fi

#################################################################
#root part
#################################################################

if [ $EUID -eq 0 ]; then

	#install epel repository
	yum install -y wget
	if [ ! -f epel-release-latest-7.noarch.rpm ]; then
		wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		rpm -Uvh epel-release-7*.rpm
	fi

	#install packages
	yum install -y rpm-build mock

	#create rhel mock template
	cp rhel.cfg /etc/mock/
	
	#create user makerpm
	id makerpm &> /dev/null || (
		useradd -G mock,wheel makerpm
		echo makerpm | passwd makerpm --stdin
	)
	
	echo "password for makerpm user is: makerpm"
	
	exit
	
fi

#################################################################
#non-root part
#################################################################

#create folder
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

#init mock
mock -r rhel --init
mock -r rhel --shell "cat /etc/system-release" -q
