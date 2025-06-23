# Script PowerShell pour generer un fichier .mxtsessions importable sur MobaXterm

###
###     Version: 1.0
###     Auteur: enguerra-n
###     Cree le: 23/06/25
###
###########################################
# Explication du script
###########################################
# Ce script permet d'importer de créer des sessions moba avec un fichier router.db créer par un serveur oxidized
# de la forme suivante : 
# CODE_EQUIPEMENT:REFERENCE_EQUIPEMENT:ADDR_IP:MARQUE_EQUIPEMENT
#
# Utilisation : 
# 1. Exécutez ce script avec le fichier router.db dans le même dossier.
# 2. Entrez le nom du dossier globale qui contiendra les sessions à créer
# 3. Le fichier sessions_import.mxtsessions sera créer.
#
# Ce script à était créer avec l'aide de claude.ai (définition des foncitons) et chatgpt (mise en forme).


# Verifie si le fichier router.db existe
if (-not (Test-Path -Path "router.db")) {
    Write-Host "Erreur: Le fichier router.db n'existe pas" -ForegroundColor Red
    exit 1
}
$folder_global_name = Read-Host "Entrez le nom du dossier à créer"
$CONFIG_FILE = "sessions_import.mxtsessions"

$categories_data = @{}
$clients_data = @{}

$router_data = Get-Content -Path "router.db"
foreach ($line in $router_data) {
    $parts = $line.Split(":")
    if ($parts.Length -ge 4) {
        $code_client = $parts[0].Trim()
        $reference_routeur = $parts[1].Trim()
        $ip = $parts[2].Trim()
        $marque = $parts[3].Trim()

        if ($code_client.Length -ge 4 -and $code_client.Substring(1,3) -match '^\d{3}$') {
            $categorie_nom = $code_client.Substring(0, 4)
        } elseif ($code_client.Length -ge 3 -and $code_client.Substring(1,2) -match '^\d{2}$') {
            $categorie_nom = $code_client.Substring(0, 3)
        } else {
            $categorie_nom = "Autres"
        }

        if (-not $categories_data.ContainsKey($categorie_nom)) {
            $categories_data[$categorie_nom] = @{
                SubRep = $categorie_nom
            }
        }

        $client_folder_name = if ($marque -and $marque -ne $code_client -and $marque.Trim() -ne "") {
            "$code_client"
        } else {
            $code_client
        }

        $client_key = "$categorie_nom\$client_folder_name"

        if (-not $clients_data.ContainsKey($client_key)) {
            $clients_data[$client_key] = @{
                ParentCategory = $categorie_nom
                Name = $client_folder_name
                Sessions = @()
            }
        }

        $session_name = "$reference_routeur -- $marque"
        $session_value = "#109#0%${ip}%22%%%-1%-1%%%22%%0%-1%0%%%-1%0%0%0%%1080%%0%0%1#MobaFont%10%0%0%0%15%236,236,236%30,30,30%180,180,192%0%-1%0%%xterm%-1%-1%_Std_Colors_0_%80%24%0%1%-1%<none>%%0#0# #-1"

        $clients_data[$client_key].Sessions += "$session_name=$session_value"
    }
}

$BOOKMARK_ID = 1
$categories_info = @{}
$clients_info = @{}

foreach ($cat_name in $categories_data.Keys | Sort-Object) {
    $categories_info[$cat_name] = @{
        ID = $BOOKMARK_ID
        SubRep = $categories_data[$cat_name].SubRep
    }
    $BOOKMARK_ID++
}

# Ne garder que les clients qui ont au moins une session
foreach ($client_key in $clients_data.Keys | Sort-Object) {
    $client_data = $clients_data[$client_key]
    if ($client_data.Sessions.Count -gt 0) {
        $parent_category_id = $categories_info[$client_data.ParentCategory].ID

        $clients_info[$client_key] = @{
            ID = $BOOKMARK_ID
            ParentID = $parent_category_id
            Name = $client_data.Name
            Sessions = $client_data.Sessions
        }
        $BOOKMARK_ID++
    }
}

# Supprimer les catégories qui ne contiennent aucun client
$used_categories = $clients_info.Values | ForEach-Object { $_.ParentID } | Select-Object -Unique
$categories_info = $categories_info.GetEnumerator() | Where-Object {
    $used_categories -contains $_.Value.ID
} | ForEach-Object {
    [PSCustomObject]@{
        Key = $_.Key
        Value = $_.Value
    }
} 

$all_bookmarks = @()

foreach ($cat_name in $categories_info.Keys | Sort-Object) {
    $cat_data = $categories_info[$cat_name].Value
    $all_bookmarks += @{
        Type = "Category"
        ID = $cat_data.ID
        Name = $cat_name
        SubRep = $cat_data.SubRep
        Sessions = @()
    }
}

foreach ($client_key in $clients_info.Keys | Sort-Object) {
    $client_data = $clients_info[$client_key]
    $parent_category_name = ($categories_info.GetEnumerator() | Where-Object { $_.Value.ID -eq $client_data.ParentID }).Key
    $client_subrep_path = "$($client_data.Name)"

    $all_bookmarks += @{
        Type = "Client"
        ID = $client_data.ID
        Name = $client_data.Name
        SubRep = "$folder_global_name\$client_subrep_path"
        Sessions = $client_data.Sessions
    }
}

# Réassignation des ID pour éviter les trous
$all_bookmarks = $all_bookmarks | Sort-Object ID
$current_id = 1
foreach ($bookmark in $all_bookmarks) {
    $bookmark.ID = $current_id
    $current_id++
}

# Génération du fichier final
$fileContent = @()
$fileContent += "[Bookmarks]"
$fileContent += "SubRep="
$fileContent += "ImgNum=42"

foreach ($bookmark in $all_bookmarks) {
    $bookmark_id = $bookmark.ID
    $bookmark_subrep = $bookmark.SubRep

    $fileContent += ""
    $fileContent += "[Bookmarks_$bookmark_id]"
    $fileContent += "SubRep=$bookmark_subrep"
    $fileContent += "ImgNum=41"

    if ($bookmark.Type -eq "Client" -and $bookmark.Sessions.Count -gt 0) {
        foreach ($session_entry in $bookmark.Sessions) {
            $fileContent += $session_entry
        }
    }
}

$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Get-Location).Path + "\$CONFIG_FILE", $fileContent, $utf8NoBomEncoding)

# Fichier de debug
$debug_file = "debug_structure.txt"
$debug_content = @()
$debug_content += "=== STRUCTURE GENEREE DANS L'ORDRE ==="
$debug_content += ""

foreach ($bookmark in $all_bookmarks) {
    $debug_content += "[$($bookmark.ID)] Type: $($bookmark.Type)"
    $debug_content += "    Nom: $($bookmark.Name)"
    $debug_content += "    SubRep: $($bookmark.SubRep)"
    if ($bookmark.Type -eq "Client") {
        $debug_content += "    Sessions: $($bookmark.Sessions.Count)"
        foreach ($session in $bookmark.Sessions) {
            $session_name = $session.Split('=')[0]
            $debug_content += "      - $session_name"
        }
    }
    $debug_content += ""
}

[System.IO.File]::WriteAllLines((Get-Location).Path + "\$debug_file", $debug_content, $utf8NoBomEncoding)

Write-Host "Fichier MobaXterm genere: $CONFIG_FILE" -ForegroundColor Green
Write-Host ""
Write-Host "Importez-le via : clic droit sur User sessions > Import sessions from file"
Write-Host ""

Write-Host "Statistiques:" -ForegroundColor Magenta
Write-Host "• Total bookmarks: $(($all_bookmarks | Measure-Object).Count)"
Write-Host "• Categories: $(($all_bookmarks | Where-Object { $_.Type -eq 'Category' } | Measure-Object).Count)"
Write-Host "• Clients: $(($all_bookmarks | Where-Object { $_.Type -eq 'Client' } | Measure-Object).Count)"
Write-Host "• Total sessions: $(($all_bookmarks | Where-Object { $_.Type -eq 'Client' } | ForEach-Object { $_.Sessions.Count } | Measure-Object -Sum).Sum)"
