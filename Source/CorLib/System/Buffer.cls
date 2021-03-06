VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "Buffer"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
'The MIT License (MIT)
'Copyright (c) 2015 Kelly Ethridge
'
'Permission is hereby granted, free of charge, to any person obtaining a copy
'of this software and associated documentation files (the "Software"), to deal
'in the Software without restriction, including without limitation the rights to
'use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
'the Software, and to permit persons to whom the Software is furnished to do so,
'subject to the following conditions:
'
'The above copyright notice and this permission notice shall be included in all
'copies or substantial portions of the Software.
'
'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
'INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
'PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
'FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
'OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
'DEALINGS IN THE SOFTWARE.
'
'
' Module: Buffer
'

''
' This class provides methods for copying manipulating arrays as byte arrays.
'
' @remarks Any array that is used in these methods are treated as byte arrays. No attention
' is paid to the type of the original array. They are manipulated as bytes.
' @include "..\DocIncludes\Buffer.html"
Option Explicit

''
' Copies the bytes from the source array to the destination array.
'
' @param Source The array to copy bytes from.
' @param SourceOffset The starting byte position to begin copying.
' @param Destination The array to receive the bytes.
' @param DestinationOffset The starting byte position to begin setting bytes.
' @param Count The number of bytes to be copied.
' @remarks <p>The arrays are treated as byte arrays, so no data-type conversion
' takes place. All indexes are in bytes, not in the type of the specific array.</p>
' <p>The lower-bound of the arrays is ignored. The first byte is at index 0.</p>
' @exceptions
' <table style="width: auto">
'   <tr>
'       <th>Exception</th><th>Condition</th>
'   </tr>
'   <tr>
'        <td><a href="ArgumentNullException.html">ArgumentNullException</a></td><td><i>Source</i> or <i>Destination</i> is uninitialized.</td>
'   </tr>
'    <tr>
'        <td><a href="ArgumentException.html">ArgumentException</a></td>
'        <td>
'           <i>Source</i> or <i>Destination</i> is not an array.<br/>
'           -or-<br/>
'           The number of bytes in <i>Source</i> is less than <i>SourceOffset</i> plus <i>Count</i>.<br/>
'           -or-<br/>
'           The number of bytes in <i>Destination</i> is less than <i>DestinationOffset</i> plus <i>Count</i>.<br/>
'        </td>
'    </tr>
'    <tr>
'        <td><a href="ArgumentOutOfRangeException.html">ArgumentOutOfRangeException</a></td><td><i>Source</i>, <i>Destination</i>, or <i>Count</i> is less than zero.</td>
'    </tr>
' </table>
Public Sub BlockCopy(ByRef Source As Variant, ByVal SourceOffset As Long, ByRef Destination As Variant, ByVal DestinationOffset As Long, ByVal Count As Long)
    Dim SourcePtr           As Long
    Dim DestinationPtr      As Long
    Dim SourceLength        As Long
    Dim DestinationLength   As Long
    
    SourcePtr = GetValidSAPtr(Source, NameOfSource)
    DestinationPtr = GetValidSAPtr(Destination, NameOfDestination)
    
    If SourceOffset < 0 Then _
        Error.ArgumentOutOfRange "SourceOffset", ArgumentOutOfRange_NeedNonNegNum
    If DestinationOffset < 0 Then _
        Error.ArgumentOutOfRange "DestinationOffset", ArgumentOutOfRange_NeedNonNegNum
    If Count < 0 Then _
        Error.ArgumentOutOfRange "Count", ArgumentOutOfRange_NeedNonNegNum
    
    SourceLength = CorArray.Length(Source) * SafeArrayGetElemsize(SourcePtr)
    DestinationLength = CorArray.Length(Destination) * SafeArrayGetElemsize(DestinationPtr)
    
    If SourceOffset + Count > SourceLength Then _
        Error.Argument Argument_InvalidOffLen
    If DestinationOffset + Count > DestinationLength Then _
        Error.Argument Argument_InvalidOffLen
    
    CopyMemory ByVal MemLong(DestinationPtr + PVDATA_OFFSET) + DestinationOffset, ByVal MemLong(SourcePtr + PVDATA_OFFSET) + SourceOffset, Count
End Sub

''
' Returns the length of the array in bytes.
'
' @param Arr The array to retrieve the size in bytes from.
' @return The size of the array in bytes.
' @remarks The size is calculated by taking the number of elements
' in the array and multiply it by the number of bytes each element is in length.
' @exceptions
' <table style="width: auto">
'   <tr>
'       <th>Exception</th><th>Condition</th>
'   </tr>
'   <tr>
'        <td><a href="ArgumentNullException.html">ArgumentNullException</a></td><td><i>Arr</i> is unintialized.</td>
'   </tr>
'    <tr>
'        <td><a href="ArgumentException.html">ArgumentException</a></td><td><i>Arr</i> is not an array.</td>
'    </tr>
' </table>
Public Function ByteLength(ByRef Arr As Variant) As Long
    Dim ArrayPtr As Long
    
    ArrayPtr = GetValidSAPtr(Arr)
    ByteLength = SafeArrayGetElemsize(ArrayPtr) * CorArray.Length(Arr)
End Function

''
' Returns a the byte value at the given byte index within an array.
'
' @param Arr The array to retrieve the byte value from.
' @param Index The byte index to read the byte at.
' @return The byte value from within the array.
' @remarks The index is based on bytes, not the size of the actual array
' elements. For example: if getting the byte from a Long array at index
' 3, then the upper 8-bits of the first element will be returned.
' <p>The lower-bound of the array is ignored. <i>Index</i> begins at 0.</p>
' @exceptions
' <table style="width: auto">
'   <tr>
'       <th>Exception</th><th>Condition</th>
'   </tr>
'   <tr>
'        <td><a href="ArgumentNullException.html">ArgumentNullException</a></td><td><i>Arr</i> is unintialized.</td>
'   </tr>
'    <tr>
'        <td><a href="ArgumentException.html">ArgumentException</a></td><td><i>Arr</i> is not an array.</td>
'    </tr>
'    <tr>
'        <td><a href="ArgumentOutOfRangeException.html">ArgumentOutOfRangeException</a></td><td><i>Index</i> is negative or greater than the length of <i>Arr</i>.</td>
'    </tr>
' </table>
Public Function GetByte(ByRef Arr As Variant, ByVal Index As Long) As Byte
    Dim ArrayPtr As Long
    
    ArrayPtr = GetValidSAPtr(Arr)
    
    If Index < 0 Or Index >= CorArray.Length(Arr) * SafeArrayGetElemsize(ArrayPtr) Then _
        Error.ArgumentOutOfRange "Index", ArgumentOutOfRange_Index

    GetByte = MemByte(MemLong(ArrayPtr + PVDATA_OFFSET) + Index)
End Function

''
' Sets the byte value at a given byte index within the array.
'
' @param Arr The array to set the byte value in.
' @param Index The byte index into the array to set the byte at.
' @param Value The byte value to set.
' @remarks The index is based on bytes, not the size of the actual array
' elements. For example: if setting the byte of a Long array at index 3
' , then the upper 8-bits of the first element will be set.
' <p>The lower-bound of the array is ignored. <i>Index</i> begins at 0.</p>
' @exceptions
' <table style="width: auto">
'   <tr>
'       <th>Exception</th><th>Condition</th>
'   </tr>
'   <tr>
'        <td><a href="ArgumentNullException.html">ArgumentNullException</a></td><td><i>Arr</i> is unintialized.</td>
'   </tr>
'    <tr>
'        <td><a href="ArgumentException.html">ArgumentException</a></td><td><i>Arr</i> is not an array.</td>
'    </tr>
'    <tr>
'        <td><a href="ArgumentOutOfRangeException.html">ArgumentOutOfRangeException</a></td><td><i>Index</i> is negative or greater than the length of <i>Arr</i>.</td>
'    </tr>
' </table>
Public Sub SetByte(ByRef Arr As Variant, ByVal Index As Long, ByVal Value As Byte)
    Dim ArrayPtr As Long
    
    ArrayPtr = GetValidSAPtr(Arr)
    
    If Index < 0 Or Index >= CorArray.Length(Arr) * SafeArrayGetElemsize(ArrayPtr) Then _
        Error.ArgumentOutOfRange "Index", ArgumentOutOfRange_Index

    MemByte(MemLong(ArrayPtr + PVDATA_OFFSET) + Index) = Value
End Sub

