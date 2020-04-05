[cmdletBinding()]
param(
[validateSet('Core', 'Royalty')]
[string]$mod = 'Core'
)

$src_dir = "Japanese"
$src_path = "jp\$mod\$src_dir"
$dst_root = 'C:\Program Files (x86)\Steam\SteamApps\common\RimWorld\Data'
$dst_path = "$dst_root\$mod\Languages"
#$archive_name = 'Japanese (ALT).tar'
$zip = 'd:\tools\7z\7za.exe'

write-host "XML validation ..."
$error_count = 0
get-childItem -literalPath $src_path *.xml -recurse | foreach-object {
	$filepath = $_.fullName
	try{
		[xml]$c = get-content $filepath -encoding utf8
	}catch{
		$error_count++
		write-host $filepath
		write-host $_
		write-host 
	}
}

if($error_count -eq 0){
	#write-host "Archive ..."
	#cd $src_path
	#$dp = join-path ".." $archive_name
	#$ret = start-process $zip -argumentlist "a -ttar", """$dp""", '*' -passthru -wait -noNewWindow
	#cd ..

	write-host "Remove ..."
	remove-item "$dst_path\$src_dir"-recurse -errorAction ignore

	write-host "Copy ..."
	copy-item $src_path -destination $dst_path -recurse -force
}

write-host "Done."
