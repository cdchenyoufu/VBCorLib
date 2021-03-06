VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "DBCSCodePageEncoding"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'The MIT License (MIT)
'Copyright (c) 2017 Kelly Ethridge
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
' Module: DBCSCodePageEncoding
'

''
' This Encoding is used to encode/decode unicode characters that can be represented
' with either one or two bytes.
'
Option Explicit
Implements IObject
Implements Encoding
Implements ICloneable

Private mCodePage           As Long
Private mIsReadOnly         As Boolean
Private mEncoderFallback    As EncoderFallback
Private mDecoderFallback    As DecoderFallback
Private mLeadingBytes(1)    As Byte

Friend Property Get CodePage() As Long
    CodePage = mCodePage
End Property

Friend Function GetCharCountCore(ByRef Bytes() As Byte, ByVal Index As Long, ByVal Count As Long, ByVal Decoder As DBCSCodePageDecoder) As Long
    Dim Flags           As Long
    Dim CharCount       As Long
    Dim LastByte        As Long
    Dim PartialCount    As Long
    
    If Decoder Is Nothing Then
        If TypeOf mDecoderFallback Is DecoderExceptionFallback Then
            Flags = MB_ERR_INVALID_CHARS
        End If
    Else
        ' though getting the char count will utilize any previously saved state
        ' stored in the decoder, it will not actually store any state in the
        ' decoder. Only the getting of chars will store any state.
        
        If TypeOf Decoder.DecoderFallback Is DecoderExceptionFallback Then
            Flags = MB_ERR_INVALID_CHARS
        End If
        
        LastByte = Decoder.LastByte
        
        If Count > 0 Then
            ' if the last byte to be processed in Bytes is a leading byte and we are not going
            ' to flush, then we expect that byte to be stored to be processed at the beginning
            ' of the next call. So we won't count it during this call by reducing the number
            ' of bytes that will be processed by one.
            If IsDBCSLeadByteEx(mCodePage, Bytes(Index + Count - 1)) And Not Decoder.Flushing Then
                Count = Count - 1
            End If
        End If
        
        ' if there was a leading byte stored in the previous call, then we will process it
        ' here along with the first byte from Bytes as a 2-byte character.
        If LastByte >= 0 Then
            mLeadingBytes(0) = LastByte
            
            If Count > 0 Then
                mLeadingBytes(1) = Bytes(Index)
                PartialCount = 2
            Else
                PartialCount = 1
            End If
            
            CharCount = CountChars(mLeadingBytes, 0, PartialCount, Flags)
            
            ' adjust what bytes in Bytes to be processed.
            Index = Index + 1
            Count = Count - 1
        End If
    End If
    
    If Count > 0 Then
        ' count the number of chars contained within Bytes using the
        ' adjusted Index and Count values.
        CharCount = CharCount + CountChars(Bytes, Index, Count, Flags)
    End If
    
    GetCharCountCore = CharCount
End Function

Private Function CountChars(ByRef Bytes() As Byte, ByVal Index As Long, ByVal Count As Long, ByVal Flags As Long) As Long
    CountChars = MultiByteToWideChar(mCodePage, MB_PRECOMPOSED Or Flags, Bytes(Index), Count, ByVal vbNullPtr, 0)

    If Err.LastDllError = ERROR_NO_UNICODE_TRANSLATION And Flags = MB_ERR_INVALID_CHARS Then
        Throw Cor.NewDecoderFallbackException(Environment.GetResourceString(Argument_InvalidCodePageBytes))
    End If
End Function

Friend Function GetCharsCore(ByRef Bytes() As Byte, ByVal ByteIndex As Long, ByVal ByteCount As Long, ByRef Chars() As Integer, ByVal CharIndex As Long, ByVal Decoder As DBCSCodePageDecoder) As Long
    Dim CharCount       As Long
    Dim Flags           As Long
    Dim LastByte        As Long
    Dim PartialCount    As Long
    
    If Decoder Is Nothing Then
        If TypeOf mDecoderFallback Is DecoderExceptionFallback Then
            Flags = MB_ERR_INVALID_CHARS
        End If
    Else
        If TypeOf Decoder.DecoderFallback Is DecoderExceptionFallback Then
            Flags = MB_ERR_INVALID_CHARS
        End If
        
        LastByte = Decoder.LastByte
        
        If ByteCount > 0 Then
            ' if the last byte to be processed in Bytes is a leading byte and we are not going
            ' to flush, then we store the last byte to be processed at the beginning
            ' of the next call and exclude it from being processed during this call.
            If IsDBCSLeadByteEx(mCodePage, Bytes(ByteIndex + ByteCount - 1)) And Not Decoder.Flushing Then
                Decoder.LastByte = Bytes(ByteIndex + ByteCount - 1)
                ByteCount = ByteCount - 1
            End If
        End If
        
        If LastByte >= 0 Then
            ' if there was a leading byte previously stored, then we will process it
            ' during this call along with the first byte in Bytes. The two bytes will
            ' be processed as a 2-byte character.
            mLeadingBytes(0) = LastByte
            
            If ByteCount > 0 Then
                mLeadingBytes(1) = Bytes(ByteIndex)
                PartialCount = 2
            Else
                PartialCount = 1
            End If
            
            If CountChars(mLeadingBytes, 0, PartialCount, Flags) > 0 Then
                CharCount = ConvertBytesToChars(mLeadingBytes, 0, PartialCount, Chars, CharIndex, Flags)
                CharIndex = CharIndex + CharCount
            End If
            
            ' since the first byte was already used, we will adjust the
            ' index and count to process the remaining bytes.
            ByteIndex = ByteIndex + 1
            ByteCount = ByteCount - 1
        End If
    End If
    
    If ByteCount > 0 Then
        CharCount = CharCount + ConvertBytesToChars(Bytes, ByteIndex, ByteCount, Chars, CharIndex, Flags)
    End If
    
    GetCharsCore = CharCount
End Function

Private Function ConvertBytesToChars(ByRef Bytes() As Byte, ByVal ByteIndex As Long, ByVal ByteCount As Long, ByRef Chars() As Integer, ByVal CharIndex As Long, ByVal Flags As Long) As Long
    ConvertBytesToChars = MultiByteToWideChar(mCodePage, MB_PRECOMPOSED Or Flags, Bytes(ByteIndex), ByteCount, Chars(CharIndex), UBound(Chars) - CharIndex + 1)

    Select Case Err.LastDllError
        Case ERROR_NO_UNICODE_TRANSLATION
            If Flags = MB_ERR_INVALID_CHARS Then
                Throw Cor.NewDecoderFallbackException(Environment.GetResourceString(Argument_InvalidCodePageBytes))
            End If
        Case ERROR_INSUFFICIENT_BUFFER
            ThrowDecoderSmallConversionBuffer
    End Select
End Function

Friend Function GetByteCountCore(ByRef Chars() As Integer, ByVal Index As Long, ByVal Count As Long) As Long
    Dim ReplacementUsed As Long
    
    If Count > 0 Then
        GetByteCountCore = WideCharToMultiByte(mCodePage, WC_NO_BEST_FIT_CHARS, Chars(Index), Count, ByVal 0&, 0, ByVal vbNullPtr, ReplacementUsed)
        
        If ReplacementUsed And TypeOf mEncoderFallback Is EncoderExceptionFallback Then
            Throw Cor.NewEncoderFallbackException(Environment.GetResourceString(Argument_InvalidCodePageChars))
        End If
    End If
End Function

Friend Function GetBytesCore(ByRef Chars() As Integer, ByVal CharIndex As Long, ByVal CharCount As Long, ByRef Bytes() As Byte, ByVal ByteIndex As Long) As Long
    Dim ReplacementUsed As Long
    Dim ReplacementChar As Long
    
    If CharCount > 0 Then
        If TypeOf mEncoderFallback Is EncoderReplacementFallback Then
            Dim ReplacementFallback As EncoderReplacementFallback
            Set ReplacementFallback = mEncoderFallback
            ReplacementChar = AscW(ReplacementFallback.DefaultString)
        Else
            ReplacementChar = vbQuestionMarkChar
        End If
        
        GetBytesCore = WideCharToMultiByte(mCodePage, WC_NO_BEST_FIT_CHARS, Chars(CharIndex), CharCount, Bytes(ByteIndex), UBound(Bytes) - ByteIndex + 1, ReplacementChar, ReplacementUsed)
        
        If Err.LastDllError = ERROR_INSUFFICIENT_BUFFER Then
            ThrowEncoderSmallConversionBuffer
        End If
        
        If ReplacementUsed And TypeOf mEncoderFallback Is EncoderExceptionFallback Then
            Throw Cor.NewEncoderFallbackException(Environment.GetResourceString(Argument_InvalidCodePageChars))
        End If
    End If
End Function

Private Function Equals(ByRef Value As Variant) As Boolean
    Dim Other As DBCSCodePageEncoding
    
    On Error GoTo Catch
    Set Other = Value
    Equals = Other.CodePage = mCodePage
    
Catch:
End Function

Private Function GetHashCode() As Long
    GetHashCode = mCodePage
End Function

Private Function ToString() As String
    ToString = MyBase.ToString(Me, App)
End Function

Private Property Get Table() As EncodingTable
    Set Table = Statics.Encoding.EncodingTable
End Property

Private Sub ThrowEncoderSmallConversionBuffer()
    Throw Cor.NewArgumentException(Environment.GetResourceString(Argument_EncodingConversionOverflowBytes, Encoding_EncodingName, TypeName(Encoding_EncoderFallback)), "Bytes")
End Sub

Private Sub ThrowDecoderSmallConversionBuffer()
    Throw Cor.NewArgumentException(Environment.GetResourceString(Argument_EncodingConversionOverflowChars, Encoding_EncodingName, TypeName(Encoding_DecoderFallback)), "Chars")
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Constructors
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Friend Sub Init(ByVal CodePage As Long)
    mCodePage = CodePage
    Set mEncoderFallback = EncoderFallback.ReplacementFallback
    Set mDecoderFallback = DecoderFallback.ReplacementFallback
    mIsReadOnly = True
End Sub

Friend Sub InitClone(ByVal Other As Encoding)
    mCodePage = Other.CodePage
    Set mEncoderFallback = Other.EncoderFallback
    Set mDecoderFallback = Other.DecoderFallback
    mIsReadOnly = False
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Encoding
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Property Get Encoding_BodyName() As String
    Encoding_BodyName = Table.BodyName(mCodePage)
End Property

Private Function Encoding_Clone() As Encoding
    Dim En As New DBCSCodePageEncoding
    En.InitClone Me
    Set Encoding_Clone = En
End Function

Private Property Get Encoding_CodePage() As Long
    Encoding_CodePage = mCodePage
End Property

Private Property Set Encoding_DecoderFallback(ByVal Value As DecoderFallback)
    If mIsReadOnly Then _
        Error.InvalidOperation InvalidOperation_ReadOnly
    If Value Is Nothing Then _
        Error.ArgumentNull "Value"
        
    Set mDecoderFallback = Value
End Property

Private Property Get Encoding_DecoderFallback() As DecoderFallback
    Set Encoding_DecoderFallback = mDecoderFallback
End Property

Private Property Set Encoding_EncoderFallback(ByVal Value As EncoderFallback)
    If mIsReadOnly Then _
        Error.InvalidOperation InvalidOperation_ReadOnly
    If Value Is Nothing Then _
        Error.ArgumentNull "Value"
        
    Set mEncoderFallback = Value
End Property

Private Property Get Encoding_EncoderFallback() As EncoderFallback
    Set Encoding_EncoderFallback = mEncoderFallback
End Property

Private Property Get Encoding_EncodingName() As String
    Encoding_EncodingName = Table.EncodingName(mCodePage)
End Property

Private Function Encoding_Equals(Value As Variant) As Boolean
    Encoding_Equals = Equals(Value)
End Function

Private Function Encoding_GetByteCount(Chars As Variant, Optional Index As Variant, Optional Count As Variant) As Long
    Dim Range           As ListRange
    Dim LocalChars()    As Integer
    
    LocalChars = AsChars(Chars)
    
    On Error GoTo Catch
    Range = ValidateGetBytes(LocalChars, Index, Count)
    
    Encoding_GetByteCount = GetByteCountCore(LocalChars, Range.Index, Range.Count)
    
    GoSub Finally
    Exit Function
    
Catch:
    GoSub Finally
    ThrowOrErr Err
Finally:
    FreeChars LocalChars
    Return
End Function

Private Function Encoding_GetBytes(Chars As Variant, Optional Index As Variant, Optional Count As Variant) As Byte()
    Dim Range           As ListRange
    Dim LocalChars()    As Integer
    
    LocalChars = AsChars(Chars)
    
    On Error GoTo Catch
    Range = ValidateGetBytes(LocalChars, Index, Count)
    
    SAPtr(Encoding_GetBytes) = SafeArrayCreateVectorEx(vbByte, 0, GetByteCountCore(LocalChars, Range.Index, Range.Count))
    GetBytesCore LocalChars, Range.Index, Range.Count, Encoding_GetBytes, 0
    
    GoSub Finally
    Exit Function
    
Catch:
    GoSub Finally
    ThrowOrErr Err
Finally:
    FreeChars LocalChars
    Return
End Function

Private Function Encoding_GetBytesEx(Chars As Variant, ByVal CharIndex As Long, ByVal CharCount As Long, Bytes() As Byte, ByVal ByteIndex As Long) As Long
    Dim LocalChars() As Integer
    
    LocalChars = AsChars(Chars)
    
    On Error GoTo Catch
    ValidateGetBytesEx LocalChars, CharIndex, CharCount, Bytes, ByteIndex
    Encoding_GetBytesEx = GetBytesCore(LocalChars, CharIndex, CharCount, Bytes, ByteIndex)
    
    GoSub Finally
    Exit Function
    
Catch:
    GoSub Finally
    ThrowOrErr Err
Finally:
    FreeChars LocalChars
    Return
End Function

Private Function Encoding_GetCharCount(Bytes() As Byte, Optional Index As Variant, Optional Count As Variant) As Long
    Dim Range As ListRange
    
    Range = ValidateGetChars(Bytes, Index, Count)
        
    Encoding_GetCharCount = GetCharCountCore(Bytes, Range.Index, Range.Count, Nothing)
End Function

Private Function Encoding_GetChars(Bytes() As Byte, Optional Index As Variant, Optional Count As Variant) As Integer()
    Dim Range As ListRange
    
    Range = ValidateGetChars(Bytes, Index, Count)
    SAPtr(Encoding_GetChars) = SafeArrayCreateVectorEx(vbInteger, 0, GetCharCountCore(Bytes, Range.Index, Range.Count, Nothing))
    GetCharsCore Bytes, Range.Index, Range.Count, Encoding_GetChars, 0, Nothing
End Function

Private Function Encoding_GetCharsEx(Bytes() As Byte, ByVal ByteIndex As Long, ByVal ByteCount As Long, Chars() As Integer, ByVal CharIndex As Long) As Long
    ValidateGetCharsEx Bytes, ByteIndex, ByteCount, Chars, CharIndex
    Encoding_GetCharsEx = GetCharsCore(Bytes, ByteIndex, ByteCount, Chars, CharIndex, Nothing)
End Function

Private Function Encoding_GetDecoder() As Decoder
    Dim Decoder As New DBCSCodePageDecoder
    Decoder.Init Me
    Set Encoding_GetDecoder = Decoder
End Function

Private Function Encoding_GetEncoder() As Encoder
    Set Encoding_GetEncoder = Cor.NewDefaultEncoder(Me)
End Function

Private Function Encoding_GetHashCode() As Long
    Encoding_GetHashCode = GetHashCode
End Function

Private Function Encoding_GetMaxByteCount(ByVal CharCount As Long) As Long
    If CharCount < 0 Then _
        Error.ArgumentOutOfRange "CharCount", ArgumentOutOfRange_NeedNonNegNum
    
    Encoding_GetMaxByteCount = CharCount
End Function

Private Function Encoding_GetMaxCharCount(ByVal ByteCount As Long) As Long
    If ByteCount < 0 Then _
        Error.ArgumentOutOfRange "ByteCount", ArgumentOutOfRange_NeedNonNegNum
    
    Encoding_GetMaxCharCount = ByteCount
End Function

Private Function Encoding_GetPreamble() As Byte()
    Encoding_GetPreamble = Cor.NewBytes
End Function

Private Function Encoding_GetString(Bytes() As Byte, Optional Index As Variant, Optional Count As Variant) As String
    Dim Range   As ListRange
    Dim Chars() As Integer
    
    Range = ValidateGetChars(Bytes, Index, Count)
    Encoding_GetString = SysAllocStringLen(vbNullPtr, GetCharCountCore(Bytes, Range.Index, Range.Count, Nothing))
    Chars = AllocChars(Encoding_GetString)
    
    On Error GoTo Catch
    GetCharsCore Bytes, Range.Index, Range.Count, Chars, 0, Nothing
    
    GoSub Finally
    Exit Function
    
Catch:
    GoSub Finally
    ThrowOrErr Err
Finally:
    FreeChars Chars
    Return
End Function

Private Property Get Encoding_HeaderName() As String
    Encoding_HeaderName = Table.HeaderName(mCodePage)
End Property

Private Property Get Encoding_IsBrowserDisplay() As Boolean
    Encoding_IsBrowserDisplay = Table.IsBrowserDisplay(mCodePage)
End Property

Private Property Get Encoding_IsBrowserSave() As Boolean
    Encoding_IsBrowserSave = Table.IsBrowserSave(mCodePage)
End Property

Private Property Get Encoding_IsMailNewsDisplay() As Boolean
    Encoding_IsMailNewsDisplay = Table.IsMailNewsDisplay(mCodePage)
End Property

Private Property Get Encoding_IsMailNewsSave() As Boolean
    Encoding_IsMailNewsSave = Table.IsMailNewsSave(mCodePage)
End Property

Private Property Get Encoding_IsReadOnly() As Boolean
    Encoding_IsReadOnly = mIsReadOnly
End Property

Private Property Get Encoding_IsSingleByte() As Boolean
    Encoding_IsSingleByte = True
End Property

Private Function Encoding_ToString() As String
    Encoding_ToString = ToString
End Function

Private Property Get Encoding_WebName() As String
    Encoding_WebName = Table.WebName(mCodePage)
End Property

Private Property Get Encoding_WindowsCodePage() As Long
    Encoding_WindowsCodePage = Table.WindowsCodePage(mCodePage)
End Property


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   ICloneable
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Function ICloneable_Clone() As Object
    Set ICloneable_Clone = Encoding_Clone
End Function


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
