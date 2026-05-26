# ================================================================
# tao_bke_ph_VBA.ps1  -  Tao tu dau, khong can mo file xlsx cu
# Chay: Set-ExecutionPolicy Bypass -Scope Process -Force
#        & "C:\Temp\bke\tao_bke_ph_VBA.ps1"
# ================================================================
# YEU CAU: Excel -> File -> Options -> Trust Center -> Trust Center Settings
#           -> Macro Settings -> tick "Trust access to VBA project object model"
# ================================================================

param([string]$OutputFile = "$PSScriptRoot\bke_ph_final.xlsm")

$ErrorActionPreference = "Stop"
$excel = $null

try {
    $dst = [System.IO.Path]::GetFullPath($OutputFile)

    Write-Host ">> Khoi dong Excel..." -ForegroundColor Cyan
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible       = $false
    $excel.DisplayAlerts = $false

    # Tao workbook moi (khong can mo file xlsx)
    Write-Host ">> Tao workbook moi..." -ForegroundColor Cyan
    $wb = $excel.Workbooks.Add()
    $ws = $wb.Worksheets.Item(1)
    $ws.Name = "BangKe"

    # ---- Du lieu co dinh ----
    Write-Host ">> Nhap du lieu..." -ForegroundColor Yellow

    # Tieu de
    $ws.Range("B1").Value  = "BANG KE CAC LOAI TIEN NOP"
    $ws.Range("B1").Font.Bold = $true
    $ws.Range("B1").Font.Size = 13

    # Header hang 2
    $ws.Range("B2").Value = "Menh gia"
    $ws.Range("C2").Value = "So to"
    $ws.Range("D2").Value = "Thanh tien"
    $ws.Range("F2").Value = "Nhap tay"
    $ws.Range("H2").Value = "NHAP"
    $ws.Range("I2").Value = ""    # o nhap so tien

    # Menh gia B3:B11
    $mg = @(500000, 200000, 100000, 50000, 20000, 10000, 5000, 2000, 1000)
    for ($i = 0; $i -lt 9; $i++) {
        $ws.Cells($i + 3, 2).Value         = $mg[$i]
        $ws.Cells($i + 3, 2).NumberFormat  = "#,##0"
        $ws.Cells($i + 3, 4).NumberFormat  = "#,##0"
    }
    $ws.Range("D12").NumberFormat = "#,##0"
    $ws.Range("I2").NumberFormat  = "#,##0"

    # Tong cong hang 12
    $ws.Range("B12").Value     = "Tong cong"
    $ws.Range("B12").Font.Bold = $true

    # Nhan so tien bang chu
    $ws.Range("A14").Value = "So tien bang chu: "
    $ws.Range("A14").Font.Bold = $true

    # Footer hang 16
    $ws.Range("A16").Value = "Nguoi nop tien"
    $ws.Range("C16").Value = "Giao dich vien"

    # Canh rong cot
    $ws.Columns("B").ColumnWidth = 14
    $ws.Columns("C").ColumnWidth = 10
    $ws.Columns("D").ColumnWidth = 16
    $ws.Columns("F").ColumnWidth = 10
    $ws.Columns("H").ColumnWidth = 8
    $ws.Columns("I").ColumnWidth = 22

    Write-Host "   OK!" -ForegroundColor Green

    # ---- Standard module VBA ----
    Write-Host ">> Them standard module VBA..." -ForegroundColor Yellow
    $vbMod = $wb.VBProject.VBComponents.Add(1)
    $vbMod.Name = "AgrisModule"

    $vbaStd = @'
' === PhanMenhGia: Phan so tien thanh cac menhgia ===
Sub PhanMenhGia(ws As Worksheet)
    Dim tongTien As Double
    tongTien = 0
    If ws.Range("I2").Value <> "" And IsNumeric(ws.Range("I2").Value) Then
        tongTien = CDbl(ws.Range("I2").Value)
    End If

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

    ' 500k: override F3
    If ws.Range("F3").Value <> "" And IsNumeric(ws.Range("F3").Value) Then
        soTo(1) = CLng(ws.Range("F3").Value)
    ElseIf MG(1) > 0 Then
        soTo(1) = CLng(Int(conLai / MG(1)))
    End If
    conLai = conLai - CDbl(soTo(1)) * MG(1)

    ' 200k: override F4
    If ws.Range("F4").Value <> "" And IsNumeric(ws.Range("F4").Value) Then
        soTo(2) = CLng(ws.Range("F4").Value)
    ElseIf MG(2) > 0 Then
        soTo(2) = CLng(Int(conLai / MG(2)))
    End If
    conLai = conLai - CDbl(soTo(2)) * MG(2)

    ' 100k xuong 1k
    For i = 3 To 9
        If MG(i) > 0 And conLai >= MG(i) Then
            soTo(i) = CLng(Int(conLai / MG(i)))
        Else
            soTo(i) = 0
        End If
        conLai = conLai - CDbl(soTo(i)) * MG(i)
    Next i

    Application.ScreenUpdating = False
    Dim tongThanhTien As Double: tongThanhTien = 0
    Dim tongSoTo As Long: tongSoTo = 0
    Dim tt As Long

    For i = 1 To 9
        tt = soTo(i) * MG(i)
        ws.Cells(i + 2, 3).Value = IIf(soTo(i) > 0, soTo(i), 0)
        ws.Cells(i + 2, 4).Value = IIf(tt > 0, tt, 0)
        tongSoTo      = tongSoTo + soTo(i)
        tongThanhTien = tongThanhTien + tt
    Next i

    ws.Range("C12").Value = tongSoTo
    ws.Range("D12").Value = tongThanhTien

    Dim chenh As Double: chenh = tongTien - tongThanhTien
    Dim D As String: D = ChrW(273)

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

' === DocSo: So thanh chu tieng Viet ===
Function DocSo(so As Double) As String
    Dim soD As Double: soD = Int(Abs(so))
    Dim D As String: D = ChrW(273)
    Dim o244 As String: o244 = ChrW(244)

    If soD = 0 Then
        DocSo = "Kh" & o244 & "ng " & D & ChrW(7891) & "ng"
        Exit Function
    End If

    Dim ti As Long, trieu As Long, nghin As Long, conLai As Long, temp As Double
    ti    = CLng(Int(soD / 1000000000))
    temp  = soD - CDbl(ti) * 1000000000
    trieu = CLng(Int(temp / 1000000))
    temp  = temp - CDbl(trieu) * 1000000
    nghin = CLng(Int(temp / 1000))
    conLai = CLng(temp - CDbl(nghin) * 1000)

    Dim r As String: r = ""
    If ti > 0     Then r = r & DocNhom(ti)     & " t" & ChrW(7927) & " "
    If trieu > 0  Then r = r & DocNhom(trieu)  & " tri" & ChrW(7879) & "u "
    If nghin > 0  Then r = r & DocNhom(nghin)  & " ngh" & ChrW(236) & "n "
    If conLai > 0 Then r = r & DocNhom(conLai)

    r = Trim(r)
    If Len(r) = 0 Then r = "kh" & o244 & "ng"
    r = UCase(Left(r, 1)) & Mid(r, 2)
    DocSo = r & " " & D & ChrW(7891) & "ng ch" & ChrW(7851) & "n"
End Function

Private Function DocNhom(n As Long) As String
    Dim tram As Integer, muoi As Integer, dv As Integer
    tram = CInt(n \ 100): muoi = CInt((n Mod 100) \ 10): dv = CInt(n Mod 10)

    Dim c(9) As String
    c(0)="": c(1)="m" & ChrW(7897) & "t": c(2)="hai": c(3)="ba"
    c(4)="b" & ChrW(7889) & "n": c(5)="n" & ChrW(259) & "m"
    c(6)="s" & ChrW(225) & "u":  c(7)="b" & ChrW(7843) & "y"
    c(8)="t" & ChrW(225) & "m":  c(9)="ch" & ChrW(237) & "n"

    Dim sT As String: sT = " tr" & ChrW(259) & "m"
    Dim sMH As String: sMH = "m" & ChrW(432) & ChrW(7901) & "i"
    Dim sM  As String: sM  = "m" & ChrW(432) & ChrW(417)  & "i"
    Dim sMt As String: sMt = " m" & ChrW(7889) & "t"
    Dim sL  As String: sL  = " l" & ChrW(259) & "m"
    Dim sLe As String: sLe = " l" & ChrW(7867) & " "

    Dim r As String: r = ""
    If tram > 0 Then
        r = c(tram) & sT
        If muoi = 0 Then
            If dv > 0 Then r = r & sLe & c(dv)
        ElseIf muoi = 1 Then
            r = r & " " & sMH
            If dv > 0 Then r = r & " " & c(dv)
        Else
            r = r & " " & c(muoi) & " " & sM
            If dv = 1 Then r = r & sMt
            ElseIf dv = 5 Then r = r & sL
            ElseIf dv > 0 Then r = r & " " & c(dv)
        End If
    Else
        If muoi = 0 Then
            r = c(dv)
        ElseIf muoi = 1 Then
            r = sMH
            If dv > 0 Then r = r & " " & c(dv)
        Else
            r = c(muoi) & " " & sM
            If dv = 1 Then r = r & sMt
            ElseIf dv = 5 Then r = r & sL
            ElseIf dv > 0 Then r = r & " " & c(dv)
        End If
    End If
    DocNhom = Trim(r)
End Function
'@

    $vbMod.CodeModule.AddFromString($vbaStd)
    Write-Host "   OK: Standard module da them!" -ForegroundColor Green

    # ---- Worksheet Change event ----
    Write-Host ">> Them Worksheet_Change event..." -ForegroundColor Yellow
    $wsVBComp = $wb.VBProject.VBComponents.Item($ws.CodeName)

    $vbaWS = @'
Private Sub Worksheet_Change(ByVal Target As Range)
    If Not Intersect(Target, Me.Range("I2,F3,F4")) Is Nothing Then
        On Error GoTo ErrHandler
        Application.EnableEvents = False
        Call PhanMenhGia(Me)
        Application.EnableEvents = True
        Exit Sub
ErrHandler:
        Application.EnableEvents = True
        If Err.Number <> 0 Then MsgBox "Loi: " & Err.Description, vbExclamation
    End If
End Sub
'@

    $wsVBComp.CodeModule.AddFromString($vbaWS)
    Write-Host "   OK: Worksheet_Change da them!" -ForegroundColor Green

    # ---- O doc so B14 ----
    Write-Host ">> Them o doc so (B14)..." -ForegroundColor Yellow
    $ws.Range("B14:I14").Merge() | Out-Null
    $ws.Range("B14").Formula             = "=DocSo(I2)"
    $ws.Range("B14").HorizontalAlignment = -4108
    $ws.Range("B14").Font.Italic         = $true
    $ws.Range("B14").Font.Size           = 11
    Write-Host "   OK!" -ForegroundColor Green

    # ---- Print area ----
    $ws.PageSetup.PrintArea          = "A1:I16"
    $ws.PageSetup.Zoom               = $false
    $ws.PageSetup.FitToPagesWide     = 1
    $ws.PageSetup.FitToPagesTall     = 1
    $ws.PageSetup.CenterHorizontally = $true
    $ws.PageSetup.PaperSize          = 9

    # ---- Luu xlsm ----
    Write-Host ">> Luu: $dst" -ForegroundColor Yellow
    $wb.SaveAs($dst, 52)
    $wb.Close($false)

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  HOAN THANH: $dst" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  Nhap so tien vao I2 -> tu phan menhgia" -ForegroundColor White
    Write-Host "  F3: so to 500k (trong = tu dong)" -ForegroundColor White
    Write-Host "  F4: so to 200k (trong = tu dong)" -ForegroundColor White
    Write-Host "  B14: so tien bang chu tieng Viet" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host "`n=== LOI === $_" -ForegroundColor Red
    if ("$_" -match "80048240|VBProject|access") {
        Write-Host "=> Bat quyen VBA: Excel->File->Options->Trust Center->Trust Center Settings" -ForegroundColor Yellow
        Write-Host "   ->Macro Settings-> tick 'Trust access to VBA project object model'" -ForegroundColor Yellow
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
