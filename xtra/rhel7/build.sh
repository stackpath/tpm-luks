#debug
if [ "$1" == "-d" ]; then
   shift
   set -x
   trap read debug
fi

#get-path
SOURCE=$0
SOURCE=$( dirname $SOURCE )
SOURCE=$( realpath $SOURCE )
SOURCE=$( dirname $SOURCE )

#################################################################
#root part
#################################################################
if [ $EUID -eq 0 ]; then
   #install packages
   yum install rpm-build mock

   #create user makerpm
   id makerpm &> /dev/null || (
      useradd -G mock,wheel makerpm
      echo makerpm | passwd makerpm --stdin
   )
   
   
   #create rhel mock template
   cp $SOURCE/install/rhel.cfg /etc/mock/

   echo "use 'su - makerpm', copy folder, then restart this script to continue"
   
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
