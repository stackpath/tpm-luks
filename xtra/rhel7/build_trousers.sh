if [ "$1" == "-d" ]; then
   shift
   set -x
   trap read debug
fi

action=$1

mkdir -p src work

url=http://sourceforge.net/projects/trousers/files/trousers/0.3.13/trousers-0.3.13.tar.gz
file=${url##*/}
dir=${file%.tar.gz}
pkg=$dir-1
spec=dist/fedora/trousers.spec
specf=${spec##*/}
   
if [ "$action" == "1" -o -z "$action" ]; then
   [ -f src/$file ] || wget $url -P src
   [ -d work/$dir ] && rm -rf work/$dir/
   (
   cd work
   tar zxf ../src/$file
   cd $dir
   sudo yum install automake autoconf pkgconfig libtool openssl-devel glibc-devel
   export PKG_CONFIG_PATH=/usr/lib64/pkgconfig
   sh ./bootstrap.sh
   CFLAGS="-L/usr/lib64 -L/opt/gnome/lib64" LDFLAGS="-L/usr/lib64 -L/opt/gnome/lib64" ./configure --libdir="/usr/local/lib64"
   )
fi

if [ "$action" == "2" -o "$action" == "3" -o -z "$action" ]; then
   cp -f src/$file ~/rpmbuild/SOURCES/
   cp -f work/$dir/$spec ~/rpmbuild/SPECS/
   rpmbuild -bs ~/rpmbuild/SPECS/$specf
   if [ "$action" == "2" -o -z "$action" ]; then
      mock -r rhel --clean
   fi
   home=$( echo ~makerpm )
   mock -r rhel --resultdir=$home/rpmbuild/RPMS/ ~/rpmbuild/SRPMS/$pkg.src.rpm --no-clean --no-cleanup-after
fi
