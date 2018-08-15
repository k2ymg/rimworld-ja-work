$src_path='Japanese'

write-host "XML validation ------------------------"
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
	write-host "Copying ------------------------"
	$location = 'c:\Program Files (x86)\Steam\SteamApps\common\RimWorld\Mods\Core\Languages\Japanese'
	remove-item -literalPath $location -force -recurse -errorAction ignore | out-null
	$dst = new-item -path $location -itemType directory
	copy-item $src_path\* -destination $dst -recurse -force
}

write-host "Done."
