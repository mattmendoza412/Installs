function Copy-FontItem
{
<#
.SYNOPSIS

    Copies a file from one location to another including files contained within DeviceObject paths.

.PARAMETER Path

    Specifies the path to the file to copy.

.PARAMETER Destination

    Specifies the path to the location where the item is to be copied.

.PARAMETER FailIfExists

    Do not copy the file if it already exists in the specified destination.

.OUTPUTS

    None or an object representing the copied item.

.EXAMPLE

    Copy-RawItem '\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy2\Windows\System32\config\SAM' 'C:\temp\SAM'

#>

    [CmdletBinding()]
    [OutputType([System.IO.FileSystemInfo])]
    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path
    )

    # Create a new dynamic assembly. An assembly (typically a dll file) is the container for modules
    $DynAssembly = New-Object System.Reflection.AssemblyName('Win32Lib')

    # Define the assembly and tell is to remain in memory only (via [Reflection.Emit.AssemblyBuilderAccess]::Run)
    $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly($DynAssembly, [Reflection.Emit.AssemblyBuilderAccess]::Run)

    # Define a new dynamic module. A module is the container for types (a.k.a. classes)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('Win32Lib', $False)

    # Define a new type (class). This class will contain our method - CopyFile
    # I'm naming it 'Kernel32' so that you will be able to call CopyFile like this:
    # [Kernel32]::CopyFile(src, dst, FailIfExists)
    $TypeBuilder = $ModuleBuilder.DefineType('gdi32', 'Public, Class')

    # Define the CopyFile method. This method is a special type of method called a P/Invoke method.
    # A P/Invoke method is an unmanaged exported function from a module - like kernel32.dll
    $PInvokeMethod = $TypeBuilder.DefineMethod('AddFontResource',
                                               [Reflection.MethodAttributes] 'Public, Static',
                                               [Bool],
                                               [Type[]] @([String]))

    #region DllImportAttribute 
    # Set the equivalent of: [DllImport("kernel32.dll", SetLastError = true, PreserveSig = true,
    #                                   CallingConvention = CallingConvention.WinApi,
    #                                   CharSet = CharSet.Unicode)]
    # Note: DefinePInvokeMethod cannot be used if SetLastError needs to be set
    $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
    $FieldArray = [Reflection.FieldInfo[]] @(
        [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
        [Runtime.InteropServices.DllImportAttribute].GetField('PreserveSig'),
        [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError'),
        [Runtime.InteropServices.DllImportAttribute].GetField('CallingConvention'),
        [Runtime.InteropServices.DllImportAttribute].GetField('CharSet')
    )

    $FieldValueArray = [Object[]] @(
        'AddFontResource',
        $True,
        $True,
        [Runtime.InteropServices.CallingConvention]::Winapi,
        [Runtime.InteropServices.CharSet]::Unicode
    )

    $SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor,
                                                                                     @('gdi32.dll'),
                                                                                     $FieldArray,
                                                                                     $FieldValueArray)

    $PInvokeMethod.SetCustomAttribute($SetLastErrorCustomAttribute)
    #endregion

    # Make our method accesible to PowerShell
    $Kernel32 = $TypeBuilder.CreateType()

    # Perform the copy
    $CopyResult = $Kernel32::AddFontResource($Path)

    if ($CopyResult -eq $False)
    {
        # An error occured. Display the Win32 error set by CopyFile
        throw ( New-Object ComponentModel.Win32Exception )
    }
    else
    {
        #Write-Output (Get-ChildItem $Destination)
    }
}


$NetworkPath = "\\andromeda\ctxcfg$\fonts\RoboTo\*"
$files = dir $NetworkPath -Filter *.otf | select name
foreach($fil in $files.name){
Copy-FontItem  c:\windows\fonts\$fil
}

