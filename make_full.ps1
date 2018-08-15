$src = 'Japanese\*'
$dst_prefix = 'rimworld-ja'

$zip = "d:\tools\7z\7za.exe"
function zip_command($src_path, $dst_path)
{
	# compress-archive will generate broken archive. do not use.
	#compress-archive -path $src_path -destinationPath $dst_path

	$ret = start-process $zip -argumentlist "a", """$dst_path""", """$src_path""" -passthru -wait -nonewwindow
	if($ret.exitcode -ne 0){
		write-host "Failed zip: $($ret.exitcode)"
		write-host "src: $($src_path)"
		write-host "dst: $($dst_path)"
		exit
	}
}

$date_part = get-date -format 'yyyyMMdd'

$dst_a = "$($dst_prefix)-$($date_part)-a.zip"
$dst_b = "$($dst_prefix)-$($date_part)-b.zip"
$dst_c = "$($dst_prefix)-$($date_part)-c.zip"

invoke-expression ".\make.ps1 -clean -trans a"
zip_command $src $dst_a

invoke-expression ".\make.ps1 -clean -trans b"
zip_command $src $dst_b

invoke-expression ".\make.ps1 -clean -trans c"
zip_command $src $dst_c
