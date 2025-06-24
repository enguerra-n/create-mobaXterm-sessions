# Script PowerShell pour générer un fichier .mxtsessions importable sur MobaXterm
###
###     Version: 1.2
###     Auteur: enguerra-n (adapté)
###     Créé le: 23/06/25
###     Modifié: 24/06/25 - Mode sans username / avec username via -u
###
param(
    [switch]$u,
    [switch]$h,
    [switch]$help
)

function Show-Help {
    Write-Host ""
    Write-Host "=== GENERATEUR DE SESSIONS MOBAXTERM ==="
    Write-Host ""
    Write-Host "Ce script génère un fichier .mxtsessions importable dans MobaXterm"
    Write-Host "à partir d'un fichier router.db créé par Oxidized."
    Write-Host ""
    Write-Host "Utilisation :"
    Write-Host "    .\script.ps1          → Génère les sessions avec un username par défaut ('admin')"
    Write-Host "    .\script.ps1 -u       → Demande les usernames pour chaque marque"
    Write-Host "    .\script.ps1 -h       → Affiche cette aide"
    Write-Host ""
    exit 0
}

if ($h -or $help) {
    Show-Help
}

Write-Host ""
Write-Host "=== GENERATEUR DE SESSIONS MOBAXTERM ===" -ForegroundColor Cyan

if (-not (Test-Path -Path "router.db")) {
    Write-Host "Erreur: Le fichier router.db n'existe pas" -ForegroundColor Red
    exit 1
}

Write-Host "Fichier router.db trouvé !" -ForegroundColor Green

# Détection des marques
$detected_brands = @()
Get-Content -Path "router.db" | ForEach-Object {
    $parts = $_.Split(":")
    if ($parts.Length -ge 4) {
        $brand = $parts[3].Trim().ToUpper()
        if ($brand -and -not $detected_brands.Contains($brand)) {
            $detected_brands += $brand
        }
    }
}

# Gestion des usernames
$brand_username_map = @{}
if ($u) {
    Write-Host ""
    Write-Host "=== CONFIGURATION DES USERNAMES PAR MARQUE ===" -ForegroundColor Cyan
    foreach ($brand in $detected_brands | Sort-Object) {
        do {
            $username_input = Read-Host "Entrez le nom d'utilisateur pour la marque '$brand'"
        } while ([string]::IsNullOrWhiteSpace($username_input))
        $brand_username_map[$brand] = $username_input
    }
    Write-Host ""
} else {
    foreach ($brand in $detected_brands) {
        $brand_username_map[$brand] = "admin"
    }
}

# Saisie du nom du dossier global
$folder_global_name = Read-Host "Entrez le nom du dossier global qui contiendra toutes les sessions"
if ([string]::IsNullOrWhiteSpace($folder_global_name)) {
    Write-Host "Erreur: Le nom du dossier ne peut pas être vide" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Traitement en cours..." -ForegroundColor Yellow

# Initialisation
$categories_data = @{}
$clients_data = @{}
$router_data = Get-Content -Path "router.db"
$total_lines = $router_data.Count
$processed_lines = 0

foreach ($line in $router_data) {
    $processed_lines++
    Write-Progress -Activity "Lecture du fichier router.db" -Status "Ligne $processed_lines sur $total_lines" -PercentComplete (($processed_lines / $total_lines) * 100)

    $parts = $line.Split(":")
    if ($parts.Length -ge 4) {
        $code_client = $parts[0].Trim()
        $reference_routeur = $parts[1].Trim()
        $ip = $parts[2].Trim()
        $marque = $parts[3].Trim()
        $marque_up = $marque.ToUpper()

        if ($code_client.Length -ge 4 -and $code_client.Substring(1,3) -match '^\d{3}$') {
            $categorie_nom = $code_client.Substring(0, 4)
        } elseif ($code_client.Length -ge 3 -and $code_client.Substring(1,2) -match '^\d{2}$') {
            $categorie_nom = $code_client.Substring(0, 3)
        } else {
            $categorie_nom = "Autres"
        }

        if (-not $categories_data.ContainsKey($categorie_nom)) {
            $categories_data[$categorie_nom] = @{ SubRep = $categorie_nom }
        }

        $client_folder_name = $code_client
        $client_key = "$categorie_nom\$client_folder_name"

        if (-not $clients_data.ContainsKey($client_key)) {
            $clients_data[$client_key] = @{
                ParentCategory = $categorie_nom
                Name = $client_folder_name
                Sessions = @()
            }
        }

        $session_name = "$reference_routeur -- $marque"
        $session_username = if ($brand_username_map.ContainsKey($marque_up)) {
            $brand_username_map[$marque_up]
        } else {
            "admin"
        }

        $session_value = "#109#0%${ip}%22%${session_username}%%-1%-1%%%%%0%0%0%%%-1%0%0%0%%1080%%0%0%1#MobaFont%10%0%0%0%15%236,236,236%30,30,30%180,180,192%0%-1%0%%xterm%-1%-1%_Std_Colors_0_%80%24%0%1%-1%<none>%%0#0# #-1"
        $clients_data[$client_key].Sessions += "$session_name=$session_value"
    }
}
Write-Progress -Activity "Lecture du fichier router.db" -Completed

# Organisation des bookmarks
$BOOKMARK_ID = 1
$categories_info = @{}
foreach ($cat in $categories_data.Keys | Sort-Object) {
    $categories_info[$cat] = @{ ID = $BOOKMARK_ID; SubRep = $categories_data[$cat].SubRep }
    $BOOKMARK_ID++
}

$clients_info = @{}
foreach ($client_key in $clients_data.Keys | Sort-Object) {
    $cd = $clients_data[$client_key]
    if ($cd.Sessions.Count -gt 0) {
        $parent_id = $categories_info[$cd.ParentCategory].ID
        $clients_info[$client_key] = @{
            ID = $BOOKMARK_ID
            ParentID = $parent_id
            Name = $cd.Name
            Sessions = $cd.Sessions
        }
        $BOOKMARK_ID++
    }
}

$used_categories = $clients_info.Values | ForEach-Object { $_.ParentID } | Select-Object -Unique
$categories_info = $categories_info.GetEnumerator() |
    Where-Object { $used_categories -contains $_.Value.ID } |
    ForEach-Object { @{ Key = $_.Key; Value = $_.Value } }

$all_bookmarks = @()
foreach ($cat in $categories_info.Keys | Sort-Object) {
    $v = $categories_info[$cat]
    $all_bookmarks += @{ Type="Category"; ID=$v.ID; Name=$cat; SubRep=$v.SubRep; Sessions=@() }
}
foreach ($client_key in $clients_info.Keys | Sort-Object) {
    $ci = $clients_info[$client_key]
    $subrep = "$folder_global_name\$($ci.Name)"
    $all_bookmarks += @{ Type="Client"; ID=$ci.ID; Name=$ci.Name; SubRep=$subrep; Sessions=$ci.Sessions }
}

# Réassignation contiguë des IDs
$all_bookmarks = $all_bookmarks | Sort-Object ID
$current_id = 1
foreach ($bm in $all_bookmarks) { $bm.ID = $current_id; $current_id++ }

# Génération du fichier sessions
Write-Host "Génération du fichier MobaXterm..." -ForegroundColor Yellow
$fileContent = @(
    "[Bookmarks]",
    "SubRep=",
    "ImgNum=42"
)
foreach ($bm in $all_bookmarks) {
    $fileContent += ""
    $fileContent += "[Bookmarks_$($bm.ID)]"
    $fileContent += "SubRep=$($bm.SubRep)"
    $fileContent += "ImgNum=41"
    if ($bm.Type -eq "Client") {
        $fileContent += $bm.Sessions
    }
}
$filePath = Join-Path -Path (Get-Location) -ChildPath "sessions_import.mxtsessions"
[System.IO.File]::WriteAllLines($filePath, $fileContent, (New-Object System.Text.UTF8Encoding $false))

# Fichier de debug
$debug = @()
$debug += "=== STRUCTURE GENERÉE ==="
$debug += "Dossier global: $folder_global_name"
$debug += "Date de génération: $(Get-Date)"
$debug += ""
$debug += "=== USERNAMES PAR MARQUE ==="
foreach ($b in $brand_username_map.Keys | Sort-Object) {
    $debug += "$b -> $($brand_username_map[$b])"
}
$debug += ""
foreach ($bm in $all_bookmarks) {
    $debug += "[$($bm.ID)] $($bm.Type) : $($bm.Name)"
    $debug += "    SubRep: $($bm.SubRep)"
    if ($bm.Type -eq "Client") {
        $debug += "    Sessions: $($bm.Sessions.Count)"
        foreach ($s in $bm.Sessions) {
            $debug += "      - " + ($s.Split('=')[0])
        }
    }
    $debug += ""
}
[System.IO.File]::WriteAllLines("debug_structure.txt", $debug, (New-Object System.Text.UTF8Encoding $false))

# Résumé final
Write-Host ""
Write-Host "=== GÉNÉRATION TERMINÉE AVEC SUCCÈS ===" -ForegroundColor Green
Write-Host ""
Write-Host "Fichiers générés :" -ForegroundColor Cyan
Write-Host "• sessions_import.mxtsessions" -ForegroundColor White
Write-Host "• debug_structure.txt" -ForegroundColor White
Write-Host ""
Write-Host "Importez dans MobaXterm via : clic droit sur 'User sessions' > 'Import sessions from file'." -ForegroundColor Yellow
Write-Host ""
Write-Host "STATISTIQUES :" -ForegroundColor Magenta
Write-Host ("• Bookmarks : " + ($all_bookmarks.Count))
Write-Host ("• Catégories : " + ($all_bookmarks | Where-Object { $_.Type -eq "Category" } | Measure-Object).Count)
Write-Host ("• Clients : " + ($all_bookmarks | Where-Object { $_.Type -eq "Client" } | Measure-Object).Count)
Write-Host ("• Sessions totales : " + ($all_bookmarks | Where-Object { $_.Type -eq "Client" } |
    ForEach-Object { $_.Sessions.Count } | Measure-Object -Sum).Sum)
Write-Host ""
