# ================================================================
# tao_bke_ph_VBA.ps1  -  Phien ban VBA toan phan
# Phan menhgia + Doc so: tat ca bang VBA, khong co cong thuc o
# Chay: PowerShell -ExecutionPolicy Bypass -File tao_bke_ph_VBA.ps1
# ================================================================
# YEU CAU:
#   Excel -> File -> Options -> Trust Center -> Trust Center Settings
#   -> Macro Settings -> tick "Trust access to the VBA project object model"
# ================================================================

param(
    [string]$SourceFile = "$PSScriptRoot\bke_ph_v2.xlsx",
    [string]$OutputFile = "$PSScriptRoot\bke_ph_final.xlsm"
)

$ErrorActionPreference = "Stop"
$excel = $null

try {
    $src = [System.IO.Path]::GetFullPath($SourceFile)
    $dst = [System.IO.Path]::GetFullPath($OutputFile)

    if (-not (Test-Path $src)) { throw "Khong tim thay: $src" }

    Write-Host ">> Khoi dong Excel..." -ForegroundColor Cyan
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible        = $false
    $excel.DisplayAlerts  = $false

    Write-Host ">> Mo: $src" -ForegroundColor Cyan
    $wb = $excel.Workbooks.Open($src)
    $ws = $wb.Worksheets.Item(1)

    # --- Xoa tat ca cong thuc cu ---
    Write-Host ">> Xoa cong thuc cu..." -ForegroundColor Yellow
    $ws.Range("C3:D11").ClearContents()
    $ws.Range("C12,D12,H3,I3").ClearContents()
    $ws.Range("I2").ClearContents()

    # ----------------------------------------------------------------
    # Module chuan: PhanMenhGia + DocSo + DocNhom
    # ----------------------------------------------------------------
    Write-Host ">> Them standard module VBA..." -ForegroundColor Yellow

    $vbMod = $wb.VBProject.VBComponents.Add(1)   # vbext_ct_StdModule
    $vbMod.Name = "AgrisModule"

    $vbaStd = @''
'' =============================================================
'' PhanMenhGia: phan so tien thanh cac menhgia (VBA, khong cong thuc)
'' Trigger: Worksheet_Change khi I2, F3, F4 thay doi
'' =============================================================
Sub PhanMenhGia(ws As Worksheet)
    Dim tongTien As Double
    tongTien = 0
    If ws.Range("I2").Value <> "" And IsNumeric(ws.Range("I2").Value) Then
        tongTien = CDbl(ws.Range("I2").Value)
    End If

    '' Doc menhgia tu cot B (B3:B11)
    Dim MG(1 To 9) As Long
    Dim i As Integer
    For i = 1 To 9
        If IsNumeric(ws.Cells(i + 2, 2).Value) Then
            MG(i) = CLng(ws.Cells(i + 2, 2).Value)
        End If
    Next i

    Dim soTo(1 To 9) As Long
    Dim conLai As Double
    conLai = tongTien

    '' 500k: kiem tra override F3
    If ws.Range("F3").Value <> "" And IsNumeric(ws.Range("F3").Value) Then
        soTo(1) = CLng(ws.Range("F3").Value)
    ElseIf MG(1) > 0 Then
        soTo(1) = CLng(Int(conLai / MG(1)))
    End If
    conLai = conLai - CDbl(soTo(1)) * MG(1)

    '' 200k: kiem tra override F4
    If ws.Range("F4").Value <> "" And IsNumeric(ws.Range("F4").Value) Then
        soTo(2) = CLng(ws.Range("F4").Value)
    ElseIf MG(2) > 0 Then
        soTo(2) = CLng(Int(conLai / MG(2)))
    End If
    conLai = conLai - CDbl(soTo(2)) * MG(2)

    '' 100k xuong 1k: tu dong tinh
    For i = 3 To 9
        If MG(i) > 0 And conLai >= MG(i) Then
            soTo(i) = CLng(Int(conLai / MG(i)))
        Else
            soTo(i) = 0
        End If
        conLai = conLai - CDbl(soTo(i)) * MG(i)
    Next i

    '' Ghi ket qua (ScreenUpdating tat de nhanh)
    Application.ScreenUpdating = False

    Dim tongThanhTien As Double: tongThanhTien = 0
    Dim tongSoTo As Long:       tongSoTo = 0

    For i = 1 To 9
        Dim tt As Long: tt = soTo(i) * MG(i)
        ws.Cells(i + 2, 3).Value = IIf(soTo(i) > 0, soTo(i), 0)
        ws.Cells(i + 2, 4).Value = IIf(tt > 0, tt, 0)
        tongSoTo      = tongSoTo + soTo(i)
        tongThanhTien = tongThanhTien + tt
    Next i

    ws.Range("C12").Value = tongSoTo
    ws.Range("D12").Value = tongThanhTien

    '' Trang thai: OK / THIEU / THUA
    Dim chenh As Double: chenh = tongTien - tongThanhTien
    Dim D As String: D = ChrW(273)   '' d-stroke

    If tongTien = 0 Then
        ws.Range("I3").Value = ""
        ws.Range("H3").Value = ""
    ElseIf Abs(chenh) < 1 Then
        ws.Range("I3").Value = "OK"
        ws.Range("H3").Value = ""
    ElseIf chenh > 0 Then
        ws.Range("I3").Value = "THI" & ChrW(7870) & "U " & Format(chenh, "#,##0") & D & ChrW(7891) & "ng"
        ws.Range("H3").Value = "THI" & ChrW(7870) & "U"
    Else
        ws.Range("I3").Value = "TH" & ChrW(7914) & "A " & Format(Abs(chenh), "#,##0") & D & ChrW(7891) & "ng"
        ws.Range("H3").Value = "TH" & ChrW(7914) & "A"
    End If

    Application.ScreenUpdating = True
End Sub

'' =============================================================
'' DocSo: chuyen so thanh chu tieng Viet (dung ChrW Unicode)
'' Vi du: DocSo(2565000) -> "Hai trieu nam tram sau muoi lam nghin dong chan"
'' =============================================================
Function DocSo(so As Double) As String
    Dim soD As Double: soD = Int(Abs(so))
    Dim D As String:   D   = ChrW(273)
    Dim o244 As String: o244 = ChrW(244)

    If soD = 0 Then
        DocSo = "Kh" & o244 & "ng " & D & ChrW(7891) & "ng"
        Exit Function
    End If

    Dim ti As Long, trieu As Long, nghin As Long, conLai As Long, temp As Double
    ti     = CLng(Int(soD / 1000000000))
    temp   = soD - CDbl(ti) * 1000000000
    trieu  = CLng(Int(temp / 1000000))
    temp   = temp - CDbl(trieu) * 1000000
    nghin  = CLng(Int(temp / 1000))
    conLai = CLng(temp - CDbl(nghin) * 1000)

    Dim result As String: result = ""
    Dim sTy    As String: sTy    = " t" & ChrW(7927) & " "
    Dim sTrieu As String: sTrieu = " tri" & ChrW(7879) & "u "
    Dim sNghin As String: sNghin = " ngh" & ChrW(236) & "n "

    If ti > 0     Then result = result & DocNhom(ti)     & sTy
    If trieu > 0  Then result = result & DocNhom(trieu)  & sTrieu
    If nghin > 0  Then result = result & DocNhom(nghin)  & sNghin
    If conLai > 0 Then result = result & DocNhom(conLai)

    result = Trim(result)
    If Len(result) = 0 Then result = "kh" & o244 & "ng"
    result = UCase(Left(result, 1)) & Mid(result, 2)

    Dim sDC As String: sDC = " " & D & ChrW(7891) & "ng ch" & ChrW(7851) & "n"
    DocSo = result & sDC
End Function

Private Function DocNhom(n As Long) As String
    Dim tram As Integer, muoi As Integer, donVi As Integer
    tram  = CInt(n \ 100)
    muoi  = CInt((n Mod 100) \ 10)
    donVi = CInt(n Mod 10)

    Dim chu(9) As String
    chu(0) = "": chu(1) = "m" & ChrW(7897) & "t": chu(2) = "hai": chu(3) = "ba"
    chu(4) = "b" & ChrW(7889) & "n": chu(5) = "n" & ChrW(259) & "m"
    chu(6) = "s" & ChrW(225) & "u":  chu(7) = "b" & ChrW(7843) & "y"
    chu(8) = "t" & ChrW(225) & "m":  chu(9) = "ch" & ChrW(237) & "n"

    Dim sTram  As String: sTram  = " tr" & ChrW(259) & "m"
    Dim sMuoiH As String: sMuoiH = "m" & ChrW(432) & ChrW(7901) & "i"
    Dim sMuoi  As String: sMuoi  = "m" & ChrW(432) & ChrW(417)  & "i"
    Dim sMot   As String: sMot   = " m" & ChrW(7889) & "t"
    Dim sLam   As String: sLam   = " l" & ChrW(259) & "m"
    Dim sLe    As String: sLe    = " l" & ChrW(7867) & " "

    Dim r As String: r = ""

    If tram > 0 Then
        r = chu(tram) & sTram
        If muoi = 0 Then
            If donVi > 0 Then r = r & sLe & chu(donVi)
        ElseIf muoi = 1 Then
            r = r & " " & sMuoiH
            If donVi > 0 Then r = r & " " & chu(donVi)
        Else
            r = r & " " & chu(muoi) & " " & sMuoi
            If donVi = 1 Then r = r & sMot
            ElseIf donVi = 5 Then r = r & sLam
            ElseIf donVi > 0 Then r = r & " " & chu(donVi)
        End If
    Else
        If muoi = 0 Then
            r = chu(donVi)
        ElseIf muoi = 1 Then
            r = sMuoiH
            If donVi > 0 Then r = r & " " & chu(donVi)
        Else
            r = chu(muoi) & " " & sMuoi
            If donVi = 1 Then r = r & sMot
            ElseIf donVi = 5 Then r = r & sLam
            ElseIf donVi > 0 Then r = r & " " & chu(donVi)
        End If
    End If

    DocNhom = Trim(r)
End Function
''@

    $vbMod.CodeModule.AddFromString($vbaStd)
    Write-Host "   OK: Standard module da them!" -ForegroundColor Green

    # ----------------------------------------------------------------
    # Worksheet module: Worksheet_Change event
    # ----------------------------------------------------------------
    Write-Host ">> Them Worksheet_Change event..." -ForegroundColor Yellow

    $wsCodeName = $ws.CodeName   # e.g. "Sheet1"
    $wsVBComp   = $wb.VBProject.VBComponents.Item($wsCodeName)

    $vbaWS = @''
Private Sub Worksheet_Change(ByVal Target As Range)
    '' Phan menhgia khi I2 thay doi; cho phep override F3(500k), F4(200k)
    If Not Intersect(Target, Me.Range("I2,F3,F4")) Is Nothing Then
        On Error GoTo ErrHandler
        Application.EnableEvents = False
        Call PhanMenhGia(Me)
        Application.EnableEvents = True
        Exit Sub
ErrHandler:
        Application.EnableEvents = True
        If Err.Number <> 0 Then MsgBox "Loi VBA: " & Err.Description, vbExclamation
    End If
End Sub
''@

    $wsVBComp.CodeModule.AddFromString($vbaWS)
    Write-Host "   OK: Worksheet_Change event da them!" -ForegroundColor Green

    # ----------------------------------------------------------------
    # O hien thi so bang chu: B14 merged, dung ham DocSo
    # ----------------------------------------------------------------
    Write-Host ">> Them o doc so bang chu (B14)..." -ForegroundColor Yellow

    $ws.Range("B14:I14").Merge() | Out-Null
    $ws.Range("B14").Formula              = "=DocSo(I2)"
    $ws.Range("B14").HorizontalAlignment  = -4108    # xlCenter
    $ws.Range("B14").Font.Italic          = $true
    $ws.Range("B14").Font.Bold            = $false
    $ws.Range("B14").Font.Size            = 11

    Write-Host "   OK!" -ForegroundColor Green

    # ----------------------------------------------------------------
    # Print area: chi in trang 1, vua A4
    # ----------------------------------------------------------------
    Write-Host ">> Cai dat print area A1:I16, fit 1 trang A4..." -ForegroundColor Yellow

    $ws.PageSetup.PrintArea           = "A1:I16"
    $ws.PageSetup.Zoom                = $false
    $ws.PageSetup.FitToPagesWide      = 1
    $ws.PageSetup.FitToPagesTall      = 1
    $ws.PageSetup.CenterHorizontally  = $true
    $ws.PageSetup.PaperSize           = 9            # xlPaperA4

    Write-Host "   OK!" -ForegroundColor Green

    # ----------------------------------------------------------------
    # Luu as xlsm
    # ----------------------------------------------------------------
    Write-Host ">> Luu: $dst" -ForegroundColor Yellow
    $wb.SaveAs($dst, 52)   # 52 = xlOpenXMLWorkbookMacroEnabled
    $wb.Close($false)

    Write-Host "" 
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  HOAN THANH: $dst"                               -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  Nhap so tien vao I2 -> phan menhgia tu dong"    -ForegroundColor White
    Write-Host "  F3: so to 500k (de trong = tu dong)"            -ForegroundColor White
    Write-Host "  F4: so to 200k (de trong = tu dong)"            -ForegroundColor White
    Write-Host "  B14: so tien bang chu tieng Viet (VBA)"         -ForegroundColor White
    Write-Host "  In Ctrl+P -> chi ra trang 1 (A1:I16)"          -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host "\n=== LOI === $_" -ForegroundColor Red
    if ($_ -match "0x80048240|VBProject|access") {
        Write-Host "=> Bat quyen VBA: Excel -> File -> Options -> Trust Center ->" -ForegroundColor Yellow
        Write-Host "   Trust Center Settings -> Macro Settings ->" -ForegroundColor Yellow
        Write-Host "   tick 'Trust access to the VBA project object model'" -ForegroundColor Yellow
    }
    exit 1
}
finally {
    if ($null -ne $excel) {
        try { $excel.Quit() } catch {}
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
}
