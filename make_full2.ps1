$zip = "d:\tools\7z\7za.exe"
function zip_command($src_path, $dst_path)
{
	# compress-archive will generate broken archive. do not use.
	#compress-archive -path $src_path -destinationPath $dst_path
	pushd $src_path
	$ret = start-process $zip -argumentlist "a", """$dst_path""", "*" -passthru -wait -nonewwindow
	if($ret.exitcode -ne 0){
		write-host "Failed zip: $($ret.exitcode)"
		write-host "src: $($src_path)"
		write-host "dst: $($dst_path)"
		exit
	}
	popd
}

rmdir tmp -recurse -force -errorAction ignore | out-null
mkdir tmp\a\Core\Languages  | out-null
mkdir tmp\b\Core\Languages  | out-null
mkdir tmp\c\Core\Languages  | out-null
mkdir tmp\a\Royalty\Languages  | out-null
mkdir tmp\b\Royalty\Languages  | out-null
mkdir tmp\c\Royalty\Languages  | out-null

$date_part = get-date -format 'yyyyMMdd'

invoke-expression ".\make2.ps1 -mod Core -trans a"
zip_command "jp\Core\Japanese" "..\..\..\tmp\a\Core\Languages\Japanese-alt.tar"
invoke-expression ".\make2.ps1 -mod Core -trans b"
zip_command "jp\Core\Japanese" "..\..\..\tmp\b\Core\Languages\Japanese-alt.tar"
invoke-expression ".\make2.ps1 -mod Core -trans c"
zip_command "jp\Core\Japanese" "..\..\..\tmp\c\Core\Languages\Japanese-alt.tar"

invoke-expression ".\make2.ps1 -mod Royalty -trans a"
zip_command "jp\Royalty\Japanese" "..\..\..\tmp\a\Royalty\Languages\Japanese-alt.tar"
invoke-expression ".\make2.ps1 -mod Royalty -trans b"
zip_command "jp\Royalty\Japanese" "..\..\..\tmp\b\Royalty\Languages\Japanese-alt.tar"
invoke-expression ".\make2.ps1 -mod Royalty -trans c"
zip_command "jp\Royalty\Japanese" "..\..\..\tmp\c\Royalty\Languages\Japanese-alt.tar"

zip_command "tmp" "..\rimworld-ja-$($date_part).zip"

