use Test::More;
plan skip_all => 'Needs Test::Pod' if not eval "use Test::Pod; 1";
all_pod_files_ok();
