if [ "$1" == "-d" ]; then
   shift
   set -x
   trap read debug
fi

action=$1

mkdir -p src work

url=http://sourceforge.net/projects/trousers/files/tpm-tools/1.3.8/tpm-tools-1.3.8.tar.gz
file=${url##*/}
dir=${file%.tar.gz}
pkg=$dir-7
spec=dist/tpm-tools.spec
specf=${spec##*/}

ext1=ftp://rpmfind.net/linux/centos/7.1.1503/os/x86_64/Packages/opencryptoki-devel-3.2-4.1.el7.x86_64.rpm
ext1f=${ext1##*/}
dep1=trousers-0.3.13-1.x86_64.rpm
dep2=trousers-devel-0.3.13-1.x86_64.rpm
   
if [ "$action" == "1" -o -z "$action" ]; then
   [ -f src/$ext1f ] || wget $ext1 -P src
   [ -f src/$file ] || wget $url -P src
   [ -d work/$dir ] && rm -rf work/$dir/
   (
   cd work
   tar zxf ../src/$file
   cd $dir
   id tss &> /dev/null || sudo useradd -r tss
   sudo yum install -y automake autoconf libtool openssl openssl-devel ../../src/$ext1f gtk+ ~/rpmbuild/RPMS/$dep1 ~/rpmbuild/RPMS/$dep2
   sudo ln -s /usr/lib64/libtspi.so.1 /usr/lib64/libtspi.so
   ./configure
   )
fi

if [ "$action" == "2" -o "$action" == "3" -o -z "$action" ]; then
   cp -f src/$file ~/rpmbuild/SOURCES/
   cp -f work/$dir/$spec ~/rpmbuild/SPECS/
   sed -i 's/libtpm_unseal.so.0/libtpm_unseal.so.?/' ~/rpmbuild/SPECS/$specf
   sed -i 's/opencryptoki-devel/opencryptoki/g' ~/rpmbuild/SPECS/$specf
   sed -ri 's/(define\s+release\s+)1/\17/g' ~/rpmbuild/SPECS/$specf
   rpmbuild -bs ~/rpmbuild/SPECS/$specf
   if [ "$action" == "2" -o -z "$action" ]; then
      mock -r rhel --clean
   fi
   home=$( echo ~makerpm )
   mock -r rhel --yum-cmd localinstall ~/rpmbuild/RPMS/$dep1
   mock -r rhel --yum-cmd localinstall ~/rpmbuild/RPMS/$dep2
   mock -r rhel --yum-cmd localinstall src/${ext1##*/}
   mock -r rhel --resultdir=$home/rpmbuild/RPMS/ ~/rpmbuild/SRPMS/$pkg.src.rpm --no-clean --no-cleanup-after
fi
