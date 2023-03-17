
function Open-FileDialog {
    param (
        [String] $path=$PSScriptRoot,
        [String] $filter="All Files (*.*)|*.*",
        [switch] $multiselect=$false
    )
    process {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            InitialDirectory = $path
            Filter = $filter
            Multiselect = $multiselect
        }
        $null = $dialog.ShowDialog()
        try {
            if ($multiselect) {
                Get-Item $dialog.FileNames    
            }
            else {
                Get-Item $dialog.FileName     
            }
        }
        catch {
            throw "`nAn error occurred, operation cancelled`n"
        }
    }
}

function Get-Folder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string]$Message = "Please select a directory.",

        [Parameter(Mandatory=$false, Position=1)]
        [string]$InitialDirectory,

        [Parameter(Mandatory=$false)]
        [System.Environment+SpecialFolder]$RootFolder = [System.Environment+SpecialFolder]::Desktop,

        [switch]$ShowNewFolderButton
    )
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description  = $Message
    $dialog.SelectedPath = $InitialDirectory
    $dialog.RootFolder   = $RootFolder
    $dialog.ShowNewFolderButton = if ($ShowNewFolderButton) { $true } else { $false }
    $selected = $null

    # force the dialog TopMost
    # Since the owning window will not be used after the dialog has been 
    # closed we can just create a new form on the fly within the method call
    $result = $dialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK){
        $selected = $dialog.SelectedPath
    }
    # clear the FolderBrowserDialog from memory
    $dialog.Dispose()
    # return the selected folder
    return $selected
} 

#$files = Open-FileDialog -multiselect -filter:"Excel Files (*.xlsx;*.xlsm)|*.xlsx;*.xlsm"
#$files | Select-Object -Property Name

$selected_dir = Get-Folder


Function showInputDialog([String]$dialogTitle, [String]$dialogText){

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $dialogTitle
    $form.Size = New-Object System.Drawing.Size(300,220)
    $form.StartPosition = 'CenterScreen'

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,140)
    $okButton.Size = New-Object System.Drawing.Size(100,23)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(280,80)
    $label.Text = $dialogText
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,100)
    $textBox.Size = New-Object System.Drawing.Size(260,20)
    $form.Controls.Add($textBox)

    $form.Topmost = $true

    $form.Add_Shown({$textBox.Select()})
    $AGP_VERSION = $form.ShowDialog()

    if ($AGP_VERSION -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $x = $textBox.Text
    }

    return $x
}

if([String]::IsNullOrEmpty($selected_dir)){
    Write-Output "您没有选择图片存储目录，将使用脚本运行目录作为图片存储目录: $PSScriptRoot..."
    $selected_dir = $PSScriptRoot;
}else{
    Write-Output "您选择的图片存储目录是: $selected_dir "
}

$path=$selected_dir   

$density_imgs = @{}
$densitys = 'mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi','nodpi';
$default_logo_file_name = "icon_launcher";

$logo_file_name = showInputDialog "图片文件名输入" "请输入图片文件名，文件名规则如下：以小写字母做首字母，随后的字符只能是由小写字母、数字、下划线组成。如果不编写，默认为icon_launcher"
if([String]::IsNullOrEmpty($logo_file_name)){
   $logo_file_name = $default_logo_file_name
   Write-Output "您没有输入图片文件名，将使用默认的: icon_launcher"
}else{
   Write-Output "您输入的图片文件名是：" $logo_file_name;   
}

$zhengze="^[a-z][a-z0-9_]{0,}$"; 
if($logo_file_name -cmatch $zhengze){
    Write-Output "你输入的图片文件名符合规则"
}else{
    $ws = New-Object -ComObject WScript.Shell  
    $ws.popup("您输入的图片文件名不符合规则，请检查! ",0,"提示",0)  
    Write-Error  "您输入的图片文件名不符合规则，脚本即将退出..."
    return;
}


$temp_path = [io.path]::combine($path,"*")
$filter_img_files = (Get-ChildItem -Path $temp_path -Include *.png,*.jpg) 2>&1 | % ToString  
Write-Output $filter_img_files

add-type -AssemblyName System.Drawing

foreach ($img_path in $filter_img_files)
{
    $img = New-Object System.Drawing.Bitmap $img_path
    $img_width = $img.Width
    $img_height = $img.Height

    if(!($img_width -eq $img_height)){ contine;}

    if($img_width -eq 48){
        $key = 'mdpi'
    }

    if($img_width -eq 72){
        $key = 'hdpi'
    }

    if($img_width -eq 96){
        $key = 'xhdpi'
    }

   if($img_width -eq 144){
       $key = 'xxhdpi'
    }

   if($img_width -eq 192){
       $key = 'xxxhdpi'
    }

    if($img_width -eq 512){
       $key = 'nodpi'
    }

    $value = $img_path
    $density_imgs[$key]= $value
}

$drawable_dir = [io.path]::combine($path, 'drawable');
$mipmap_dir = [io.path]::combine($path, 'mipmap');


New-Item  -Force -Path $drawable_dir -ItemType Directory
New-Item  -Force -Path $mipmap_dir -ItemType Directory

foreach ($density in $densitys)
{


    $drawable_density_dir_name="drawable-" + $density;
    $mipmap_density_dir_name="mipmap-" + $density;
    $drawable_density_dir = [io.path]::combine($drawable_dir, $drawable_density_dir_name);
    $mipmap_density_dir = [io.path]::combine($mipmap_dir, $mipmap_density_dir_name);


    New-Item   -Force -Path $drawable_density_dir -ItemType Directory
    New-Item   -Force -Path $mipmap_density_dir -ItemType Directory


    $filename = (Get-ChildItem -Path $density_imgs[$density] -Name) 2>&1 | % ToString
    $suffix = (Get-ChildItem -Path $density_imgs[$density]).Extension 2>&1 | % ToString

    Write-Output "filename:$filename, suffix:$suffix"


    $drawable_density_file =  [io.path]::combine($drawable_density_dir, $filename);
    $mipmap_density_file =  [io.path]::combine($mipmap_density_dir, $filename);


    $dest_file_name_with_suffix = If ($density -eq "nodpi") { $logo_file_name+"_512" + $suffix  } Else { $logo_file_name + $suffix  }


    $dest_drawable_file =[io.path]::combine($drawable_density_dir, $dest_file_name_with_suffix);
    $dest_mipmap_file =  [io.path]::combine($mipmap_density_dir, $dest_file_name_with_suffix);


    try{  

        if(Test-Path $dest_drawable_file){
             
        }else{
            Copy-Item -Force -Path  $density_imgs[$density] -Destination $drawable_density_dir
            Rename-Item -Force -Path  $drawable_density_file -NewName ($dest_file_name_with_suffix);
        }
    }catch{
        
    }


    try{
       
        if(Test-Path $dest_mipmap_file){
     
        }
        else{
             Copy-Item -Force -Path  $density_imgs[$density] -Destination $mipmap_density_dir
            Rename-Item -Force -Path  $mipmap_density_file -NewName ($dest_file_name_with_suffix);
        }
    }catch{
            
    }
}

 $ws = New-Object -ComObject WScript.Shell  
 $wsr = $ws.popup("处理后的图片已保存到目录:$path",0,"提示",0)

if($wsr -eq 1){   
    Set-Clipboard -Value $path
    
    $ws = New-Object -ComObject WScript.Shell  
    $ws.popup("目标图片保存路径已复制，您可以粘贴到文件管理器地址栏进行打开",0,"提示",0)  
}



      
