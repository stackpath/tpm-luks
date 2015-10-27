if [ "$1" == "-d" ]; then
   shift
   set -x
   trap read debug
fi

action=$1

mkdir -p src work

url=https://github.com/Sirrix-AG/TrustedGRUB2/archive/1.2.1.tar.gz
file=TrustedGRUB2-1.2.1.tar.gz
dir=${file%.tar.gz}
pkg=$dir-1.el7
spec=dist/TrustedGRUB2.spec
specf=${spec##*/}

ext1=http://mirror.centos.org/centos/7/os/x86_64/Packages/guile-2.0.9-5.el7.x86_64.rpm
ext2=http://mirror.centos.org/centos/7/os/x86_64/Packages/autogen-5.18-5.el7.x86_64.rpm
specu=TrustedGRUB2.spec
   
if [ "$action" == "1" -o -z "$action" ]; then
   [ -f src/${ext1##*/} ] || wget $ext1 -P src
   [ -f src/${ext2##*/} ] || wget $ext2 -P src
   [ -f src/$specu ] || cp $specu src
   [ -f src/$file ] || wget $url -O src/$file --no-check-certificate
fi

if [ "$action" == "2" -o "$action" == "3" -o -z "$action" ]; then
   [ -d work/$dir ] && rm -rf work/$dir/
   (
   cd work
   tar zxf ../src/$file
   cp -f ../src/$specu $dir/
   tar zcf $file $dir/
   )
   cp -f work/$file ~/rpmbuild/SOURCES/
   cp -f work/$dir/$specf ~/rpmbuild/SPECS/
   rpmbuild -bs ~/rpmbuild/SPECS/$specf
   if [ "$action" == "2" -o -z "$action" ]; then
      mock -r rhel --clean
   fi
   home=$( echo ~makerpm )
   mock -r rhel --yum-cmd localinstall src/${ext1##*/}
   mock -r rhel --yum-cmd localinstall src/${ext2##*/}
   mock -r rhel --shell "sed -i 's/--strict-build-id//g' /usr/lib/rpm/macros"
   mock -r rhel --resultdir=$home/rpmbuild/RPMS/ ~/rpmbuild/SRPMS/$pkg.src.rpm --no-clean --no-cleanup-after
fi
