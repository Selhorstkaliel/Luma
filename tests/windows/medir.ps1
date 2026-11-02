# Medição de RAM e boot do Windows 11 na VM de comparação do CI (scripts/ci/vm-windows.sh), com o mesmo
# formato e o mesmo método do Luma (tests/vm/guest/luma-ci-medicao.sh): espera a sessão, 120 s parado,
# RAM usada = total - disponível (disponível = livre + em espera, como o MemAvailable do Linux), 3 boots.
# Saída pela COM1 (serial do QEMU), linhas "LUMACI ...". Arquivo do Projeto Luma.
$ErrorActionPreference = 'Continue'
$dir = 'C:\luma'
$contador = Join-Path $dir 'boot-n.txt'
$n = 1
if (Test-Path $contador) { $n = [int](Get-Content $contador) + 1 }
Set-Content -Path $contador -Value $n
function Diga([string]$texto) {
    Add-Content -Path (Join-Path $dir 'medicao.txt') -Value $texto
    try {
        $p = New-Object System.IO.Ports.SerialPort 'COM1', 115200
        $p.Open(); $p.WriteLine("LUMACI $texto"); $p.Close()
    } catch { }
}
$os = Get-CimInstance Win32_OperatingSystem
Diga "BEGIN medicao boot=$n $($os.Caption) $($os.Version)"
# Tempo do início do boot até a sessão do usuário (este script roda no login)
$logon_s = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalSeconds, 1)
for ($i = 0; $i -lt 150 -and -not (Get-Process explorer -ErrorAction SilentlyContinue); $i++) { Start-Sleep 2 }
Start-Sleep 120
$os = Get-CimInstance Win32_OperatingSystem
$total = [math]::Round($os.TotalVisibleMemorySize / 1024)
$disp = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes
# Tempo de boot do próprio Windows (evento 100 do Diagnostics-Performance), quando existir
$ev = Get-WinEvent -FilterHashtable @{LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100} -MaxEvents 1 -ErrorAction SilentlyContinue
$boot_evt = 'nd'
if ($ev) {
    $bt = (([xml]$ev.ToXml()).Event.EventData.Data | Where-Object Name -eq 'BootTime').'#text'
    if ($bt) { $boot_evt = [math]::Round([double]$bt / 1000, 1) }
}
Diga "MED boot=$n usada_mib=$($total - $disp) disponivel_mib=$disp shmem_mib=0 boot_s=$logon_s boot_evento_s=$boot_evt"
# Os 15 processos com maior conjunto de trabalho privado (o Windows não tem PSS; é a medida mais próxima)
Get-Process | Sort-Object PrivateMemorySize64 -Descending | Select-Object -First 15 | ForEach-Object {
    Diga "MEDPROC boot=$n pss_kib=$([math]::Round($_.PrivateMemorySize64 / 1024)) comm=$($_.ProcessName)"
}
if ($n -lt 3) {
    Diga "REBOOT boot=$n"
    Restart-Computer -Force
} else {
    Diga "END medicao"
    Stop-Computer -Force
}
