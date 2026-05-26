# ================================================================
# tao_bke_ph_final.ps1
# Tạo file bke_ph_final.xlsm với VBA đọc số tiếng Việt
# Chạy: PowerShell -ExecutionPolicy Bypass -File tao_bke_ph_final.ps1
# ================================================================
# YÊU CẦU TRƯỚC KHI CHẠY:
#   Excel → File → Options → Trust Center → Trust Center Settings
#   → Macro Settings → tick "Trust access to the VBA project object model"
# ================================================================

param(
    [string]$SourceFile = "$PSScriptRoot\bke_ph_v2.xlsx",
    [string]$OutputFile = "$PSScriptRoot\bke_ph_final.xlsm"
)

$ErrorActionPreference = "Stop"
$excel = $null

try {
    $sourceFullPath = [System.IO.Path]::GetFullPath($SourceFile)
    $outputFullPath = [System.IO.Path]::GetFullPath($OutputFile)

    if (-not (Test-Path $sourceFullPath)) {
        throw "Khong tim thay file nguon: $sourceFullPath"
    }

    Write-Host ">> Khoi dong Excel..." -ForegroundColor Cyan
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    Write-Host ">> Mo: $sourceFullPath" -ForegroundColor Cyan
    $wb = $excel.Workbooks.Open($sourceFullPath)
    $ws = $wb.Worksheets.Item(1)

    # ------------------------------------------------------------------
    # Them VBA Module
    # ------------------------------------------------------------------
    Write-Host ">> Them module VBA DocSo..." -ForegroundColor Yellow

    $vbComp = $wb.VBProject.VBComponents.Add(1)   # 1 = vbext_ct_StdModule
    $vbComp.Name = "DocSoModule"

    # Toan bo VBA dung ChrW() cho tieng Viet de tranh loi encoding
    $vbaCode = @'
' ===========================================================
' DocSo: Chuyen so tien thanh chu tieng Viet
' Vi du: DocSo(2565000) -> "Hai trieu nam tram sau muoi lam nghin dong chan"
' ===========================================================
Function DocSo(so As Double) As String
    Dim soD As Double
    soD = Int(Abs(so))

    ' Tieng Viet bang ChrW (Unicode)
    Dim D As String: D = ChrW(273)              ' d-gach-ngang (d stroke)
    Dim o244 As String: o244 = ChrW(244)        ' o-mu (o circumflex)

    If soD = 0 Then
        DocSo = "Kh" & o244 & "ng " & D & ChrW(7891) & "ng"
        Exit Function
    End If

    ' Tach thanh phan
    Dim ti As Long, trieu As Long, nghin As Long, conLai As Long
    Dim temp As Double

    ti     = CLng(Int(soD / 1000000000))
    temp   = soD - CDbl(ti) * 1000000000
    trieu  = CLng(Int(temp / 1000000))
    temp   = temp - CDbl(trieu) * 1000000
    nghin  = CLng(Int(temp / 1000))
    conLai = CLng(temp - CDbl(nghin) * 1000)

    Dim result As String
    result = ""

    ' Cac don vi lon
    Dim sTy As String:    sTy    = " t" & ChrW(7927) & " "          ' " ty "
    Dim sTrieu As String: sTrieu = " tri" & ChrW(7879) & "u "       ' " trieu "
    Dim sNghin As String: sNghin = " ngh" & ChrW(236) & "n "        ' " nghin "

    If ti > 0     Then result = result & DocNhom(ti)     & sTy
    If trieu > 0  Then result = result & DocNhom(trieu)  & sTrieu
    If nghin > 0  Then result = result & DocNhom(nghin)  & sNghin
    If conLai > 0 Then result = result & DocNhom(conLai)

    result = Trim(result)
    If Len(result) = 0 Then result = "kh" & o244 & "ng"

    ' Viet hoa chu dau
    result = UCase(Left(result, 1)) & Mid(result, 2)

    ' " dong chan"
    Dim sDC As String
    sDC = " " & D & ChrW(7891) & "ng ch" & ChrW(7851) & "n"

    DocSo = result & sDC
End Function

' -----------------------------------------------------------
' DocNhom: Doc nhom 3 chu so (0-999)
' -----------------------------------------------------------
Private Function DocNhom(n As Long) As String
    Dim tram As Integer, muoi As Integer, donVi As Integer
    tram  = CInt(n \ 100)
    muoi  = CInt((n Mod 100) \ 10)
    donVi = CInt(n Mod 10)

    ' Ten cac chu so (dung ChrW)
    Dim chu(9) As String
    chu(0) = ""
    chu(1) = "m" & ChrW(7897) & "t"        ' "mot"   o-mu-dau-nang
    chu(2) = "hai"
    chu(3) = "ba"
    chu(4) = "b" & ChrW(7889) & "n"        ' "bon"   o-mu-dau-sac
    chu(5) = "n" & ChrW(259) & "m"         ' "nam"   a-bret
    chu(6) = "s" & ChrW(225) & "u"         ' "sau"   a-sac
    chu(7) = "b" & ChrW(7843) & "y"        ' "bay"   a-hoi
    chu(8) = "t" & ChrW(225) & "m"         ' "tam"   a-sac
    chu(9) = "ch" & ChrW(237) & "n"        ' "chin"  i-sac

    ' Cum tu co san
    Dim sTram  As String: sTram   = " tr" & ChrW(259) & "m"                      ' " tram"
    Dim sMuoi  As String: sMuoi   = "m" & ChrW(432) & ChrW(417) & "i"            ' "muoi" (khong dau)
    Dim sMuoiH As String: sMuoiH  = "m" & ChrW(432) & ChrW(7901) & "i"           ' "muoi" (dau huyen) cho 10-19
    Dim sMot   As String: sMot    = " m" & ChrW(7889) & "t"                      ' " mot" (sau muoi: 21,31..)
    Dim sLam   As String: sLam    = " l" & ChrW(259) & "m"                       ' " lam" (sau muoi: 25,35..)
    Dim sLe    As String: sLe     = " l" & ChrW(7867) & " "                      ' " le " (101, 205..)

    Dim result As String
    result = ""

    If tram > 0 Then
        result = chu(tram) & sTram
        If muoi = 0 Then
            If donVi > 0 Then
                result = result & sLe & chu(donVi)
            End If
        ElseIf muoi = 1 Then
            result = result & " " & sMuoiH
            If donVi > 0 Then
                result = result & " " & chu(donVi)
            End If
        Else
            result = result & " " & chu(muoi) & " " & sMuoi
            If donVi = 1 Then
                result = result & sMot
            ElseIf donVi = 5 Then
                result = result & sLam
            ElseIf donVi > 0 Then
                result = result & " " & chu(donVi)
            End If
        End If
    Else
        If muoi = 0 Then
            result = chu(donVi)
        ElseIf muoi = 1 Then
            result = sMuoiH
            If donVi > 0 Then
                result = result & " " & chu(donVi)
            End If
        Else
            result = chu(muoi) & " " & sMuoi
            If donVi = 1 Then
                result = result & sMot
            ElseIf donVi = 5 Then
                result = result & sLam
            ElseIf donVi > 0 Then
                result = result & " " & chu(donVi)
            End If
        End If
    End If

    DocNhom = Trim(result)
End Function
'@

    $vbComp.CodeModule.AddFromString($vbaCode)
    Write-Host "   OK: Da them VBA module!" -ForegroundColor Green

    # ------------------------------------------------------------------
    # Them cong thuc DocSo vao o B14 (merge B14:I14)
    # ------------------------------------------------------------------
    Write-Host ">> Them o doc so bang chu (B14:I14)..." -ForegroundColor Yellow

    # Merge B14:I14 de hien thi chu rong hon
    $ws.Range("B14:I14").Merge() | Out-Null
    $ws.Range("B14").Formula = "=DocSo(I2)"
    $ws.Range("B14").HorizontalAlignment = -4108   # xlCenter
    $ws.Range("B14").Font.Italic  = $true
    $ws.Range("B14").Font.Bold    = $false
    $ws.Range("B14").Font.Color   = [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::DarkBlue)
    $ws.Range("B14").Font.Size    = 11

    Write-Host "   OK: Da them o doc so!" -ForegroundColor Green

    # ------------------------------------------------------------------
    # Cai dat in: chi in trang 1 (A1:I16), vua khit 1 trang A4
    # ------------------------------------------------------------------
    Write-Host ">> Cai dat print area chi in trang 1..." -ForegroundColor Yellow

    With $ws.PageSetup {
        $_.PrintArea            = "A1:I16"
        $_.Zoom                 = $false          # Tat zoom de FitToPages hoat dong
        $_.FitToPagesWide       = 1               # Vua 1 trang ngang
        $_.FitToPagesTall       = 1               # Vua 1 trang doc
        $_.CenterHorizontally   = $true
        $_.PaperSize            = 9               # xlPaperA4
    }

    Write-Host "   OK: Print area = A1:I16, FitToPage 1x1!" -ForegroundColor Green

    # ------------------------------------------------------------------
    # Luu as xlsm
    # ------------------------------------------------------------------
    Write-Host ">> Luu: $outputFullPath" -ForegroundColor Yellow

    $wb.SaveAs($outputFullPath, 52)   # 52 = xlOpenXMLWorkbookMacroEnabled (.xlsm)
    $wb.Close($false)

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  HOAN THANH: $outputFullPath" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  - Nhap so tien vao o I2" -ForegroundColor White
    Write-Host "  - O B14 tu hien so bang chu tieng Viet" -ForegroundColor White
    Write-Host "  - In (Ctrl+P) chi ra trang 1 (A1:I16)" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "=== LOI ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.Message -match "0x80048240|VBProject|access") {
        Write-Host ""
        Write-Host "=> Can bat quyen VBA:" -ForegroundColor Yellow
        Write-Host "   Excel -> File -> Options -> Trust Center -> Trust Center Settings" -ForegroundColor Yellow
        Write-Host "   -> Macro Settings -> tick 'Trust access to VBA project object model'" -ForegroundColor Yellow
    }
    exit 1
}
finally {
    if ($null -ne $excel) {
        try { $excel.Quit() } catch {}
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}
