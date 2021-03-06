VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "StringWriter"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
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
' Module: StringWriter
'

''
' Provides a set of functions for writing to a string.
'
' @see Constructors
' @see TextWriter
'
Option Explicit
Implements IObject
Implements TextWriter

Private mOutput     As New StringBuilder
Private mProvider   As IFormatProvider
Private mEncoding   As New UnicodeEncoding
Private mNewLine    As String
Private mIsClosed   As Boolean


''
' Returns the encoding in which the output is written.
'
' @return The encoding of the output string.
'
Public Property Get Encoding() As Encoding
    Set Encoding = mEncoding
End Property

''
' Returns the format provider the writer uses for formatting values.
'
' @return The format provider used by the writer.
' @remarks The format provider used is the returned by the current culture.
'
Public Property Get FormatProvider() As IFormatProvider
    If mProvider Is Nothing Then
        Set mProvider = CultureInfo.CurrentCulture
    End If
    
    Set FormatProvider = mProvider
End Property

''
' Returns the string currently used to represent a new-line set of characters.
'
' @return The new-line set of characters.
' @remarks The default is CarriageReturn-LineFeed.
'
Public Property Get NewLine() As String
    NewLine = mNewLine
End Property

''
' Sets the string to be used as the new-line set of characters.
'
' @param Value The new-line set of characters.
' @remarks The default is CarriageReturn-LineFeed.
'
Public Property Let NewLine(ByRef Value As String)
    If StrPtr(Value) = vbNullPtr Then
        mNewLine = vbCrLf
    Else
        mNewLine = Value
    End If
End Property

''
' Closes the writer
'
Public Sub CloseWriter()
    mIsClosed = True
End Sub

''
' Writes any buffered data to the underlying string.
'
' @remarks Since the data is directly written to the underlying string,
' this function does nothing. It is here to maintain interface consistency.
'
Public Sub Flush()
    ' does nothing
End Sub

''
' Returns the underlying stringbuilder being used to write to the string.
'
' @return The StringBuilder being used to write to the string.
'
Public Function GetStringBuilder() As StringBuilder
    Set GetStringBuilder = mOutput
End Function

''
' Writes a text representation of the value to the underlying stream using both the
' format provider and encoding objects.
'
' @param Value The value to be written to the stream.
' @param Args An array of zero or more values to be formatted and written.
' @remarks This method uses the composite formatting feature to convert the value
' to its text representation and embed it in a string.
'
Public Sub WriteValue(ByRef Value As Variant, ParamArray Args() As Variant)
    Dim SwappedArgs() As Variant
    Helper.Swap4 ByVal ArrPtr(SwappedArgs), ByVal Helper.DerefEBP(16)
    WriteCore Value, SwappedArgs
End Sub

''
' Writes the string representation of the characters to the stream using both the
' format provider and encoding objects.
'
' @param Chars The characters to be written.
' @param Index The beginning index within the Chars array to begin writing to the stream.
' @param Count The number of characters to write to the stream.
' @remarks This method uses the composite formatting feature to convert the value
' to its text representation and embed it in a string.
'
Public Sub WriteChars(ByRef Chars() As Integer, Optional ByRef Index As Variant, Optional ByRef Count As Variant)
    ValidateArrayRange Chars, Index, Count, NameOfChars
    mOutput.Append Chars, Index, Count
End Sub

''
' Writes a text representation of the value followed by a NewLine to the underlying stream using both the
' format provider and encoding objects.
'
' @param Values An array of args containing a value or composite formatting string and a list
' of args to be formatted.
' @remarks This method uses the composite formatting feature to convert the value
' to its text representation and embed it in a string.
'
Public Sub WriteLine(ParamArray Values() As Variant)
    Dim SwappedArgs() As Variant
    Helper.Swap4 ByVal ArrPtr(SwappedArgs), ByVal Helper.DerefEBP(12)
    WriteLineCore SwappedArgs
End Sub

''
' Writes the string representation of the characters followed by a NewLine to the stream using both the
' format provider and encoding objects.
'
' @param Chars The characters to be written.
' @param Index The beginning index within the Chars array to begin writing to the stream.
' @param Count The number of characters to write to the stream.
' @remarks Both Index and Count must be excluded or included. Neither argument can be supplied individually.
'
Public Sub WriteLineChars(ByRef Chars() As Integer, Optional ByRef Index As Variant, Optional ByRef Count As Variant)
    WriteChars Chars, Index, Count
    mOutput.AppendString mNewLine
End Sub

''
' Returns a string representation of this object instance.
'
' @return String representing this instance.
Public Function ToString() As String
    ToString = mOutput.ToString
End Function

''
' Returns a boolean indicating if the value and this object
' instance are the same instance.
'
' @param Value The value to compare equality to.
' @return Boolean indicating equality.
Public Function Equals(ByRef Value As Variant) As Boolean
    Equals = MyBase.Equals(Me, Value)
End Function

''
' Returns a pseudo-unique number identifying this instance.
'
' @return Pseudo-unique number identifying this instance.
Public Function GetHashCode() As Long
    GetHashCode = MyBase.GetHashCode(Me)
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Constructors
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub Class_Initialize()
    mNewLine = Environment.NewLine
End Sub

Friend Sub Init(ByVal sb As StringBuilder, ByVal Provider As IFormatProvider)
    Set mOutput = sb
    Set mProvider = Provider
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Helpers
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub VerifyIsOpen()
    If mIsClosed Then
        Error.ObjectDisposed ObjectDisposed_WriterClosed
    End If
End Sub

Private Sub WriteLineCore(ByRef Args() As Variant)
    Dim Length As Long
    
    VerifyIsOpen
    
    On Error GoTo Catch
    Length = Len1D(Args)

    If Length > 0 Then
        Dim Shifted() As Variant
        Shifted = ShiftArguments(Args)
        WriteCore Args(LBound(Args)), Shifted
    End If

    mOutput.AppendString mNewLine
    GoSub Finally
    Exit Sub
    
Catch:
    GoSub Finally
    Throw
Finally:
    FreeArguments Shifted
    Return
End Sub

Private Sub WriteCore(ByRef Value As Variant, ByRef Args() As Variant)
    VerifyIsOpen
    
    Dim s As String
    s = Object.ToString(Value, Provider:=FormatProvider)
    
    If Len1D(Args) = 0 Then
        mOutput.AppendString s
    Else
        mOutput.AppendFormatArrayEx FormatProvider, s, Args
    End If
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   IObject
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Function IObject_Equals(Value As Variant) As Boolean
    IObject_Equals = Equals(Value)
End Function

Private Function IObject_GetHashCode() As Long
    IObject_GetHashCode = GetHashCode
End Function

Private Function IObject_ToString() As String
    IObject_ToString = ToString
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   TextWriter
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub TextWriter_CloseWriter()
    CloseWriter
End Sub

Private Property Get TextWriter_Encoding() As Encoding
    Set TextWriter_Encoding = Encoding
End Property

Private Function TextWriter_Equals(Value As Variant) As Boolean
    TextWriter_Equals = Equals(Value)
End Function

Private Sub TextWriter_Flush()
    Flush
End Sub

Private Property Get TextWriter_FormatProvider() As IFormatProvider
    Set TextWriter_FormatProvider = FormatProvider
End Property

Private Function TextWriter_GetHashCode() As Long
    TextWriter_GetHashCode = GetHashCode
End Function

Private Property Let TextWriter_NewLine(ByVal RHS As String)
    NewLine = RHS
End Property

Private Property Get TextWriter_NewLine() As String
    TextWriter_NewLine = NewLine
End Property

Private Function TextWriter_ToString() As String
    TextWriter_ToString = ToString
End Function

Private Sub TextWriter_WriteChars(Chars() As Integer, Optional Index As Variant, Optional Count As Variant)
    WriteChars Chars, Index, Count
End Sub

Private Sub TextWriter_WriteLine(ParamArray Value() As Variant)
    Dim SwappedArgs() As Variant
    Helper.Swap4 ByVal ArrPtr(SwappedArgs), ByVal Helper.DerefEBP(12)
    WriteLineCore SwappedArgs
End Sub

Private Sub TextWriter_WriteLineChars(Chars() As Integer, Optional Index As Variant, Optional Count As Variant)
    WriteLineChars Chars, Index, Count
End Sub

Private Sub TextWriter_WriteValue(ByRef Value As Variant, ParamArray Args() As Variant)
    Dim SwappedArgs() As Variant
    Helper.Swap4 ByVal ArrPtr(SwappedArgs), ByVal Helper.DerefEBP(16)
    WriteCore Value, SwappedArgs
End Sub
