POHJOINEN_OUT_DIR=$1
shift 1
$@ || exit

#export COLORBT_SHOW_HIDDEN=1
#RUST_BACKTRACE=1

TOKEN=$(cat token.txt) \
DB_PATH=./doge \
BWRAP=$(which bwrap) \
PERL=$(which perl) \
PRLIMIT=$(which prlimit) \
TIMEOUT=$(which timeout) \
ALLOW_DIRS=$BWRAP,$PRLIMIT,$TIMEOUT,$PERL,/usr/lib,/usr/lib64,/lib64,/usr/share/perl5 \
"./target/$POHJOINEN_OUT_DIR/perlsub"
unset POHJOINEN_OUT_DIR
