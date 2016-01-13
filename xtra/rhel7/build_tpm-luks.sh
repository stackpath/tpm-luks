if [ "$1" == "-d" ]; then
   shift
   set -x
   trap read debug
fi

action=$1

mkdir -p src work

url=https://github.com/momiji/tpm-luks
file=${url##*/}-0.8.tar.gz
dir=${file%.tar.gz}
pkg=$dir-5.el7
spec=tpm-luks.spec
specf=${spec##*/}

if [ "$action" == "1" -o -z "$action" ]; then
   [ -f src/$file ] || (
      [ -d src/$dir ] && rm -rf src/$dir
      git clone $url src/$dir
      (
      cd src
      tar zcf $file --exclude .git* $dir
      )
   )
   [ -d work/$dir ] && rm -rf work/$dir/
   (
   cd work
   tar zxf ../src/$file
   cd $dir
   sudo yum install -y automake autoconf libtool openssl openssl-devel
   autoreconf -ivf
   autoreconf -ivf
   ./configure
   )
fi

if [ "$action" == "2" -o "$action" == "3" -o -z "$action" ]; then
   cp src/$file ~/rpmbuild/SOURCES/
   cp work/$dir/$spec ~/rpmbuild/SPECS/
   rpmbuild -bs ~/rpmbuild/SPECS/$specf
   if [ "$action" == "2" -o -z "$action" ]; then
      mock -r rhel --clean
   fi
   home=$( echo ~makerpm )
   mock -r rhel --resultdir=$home/rpmbuild/RPMS/ ~/rpmbuild/SRPMS/$pkg.src.rpm --no-clean --no-cleanup-after
fi
