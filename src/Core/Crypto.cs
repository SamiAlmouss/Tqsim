using System;
using System.IO;
using System.Text;
using System.Security;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Text.Json;
#pragma warning disable SYSLIB0060 // Retain .NET Core compatible PBKDF2 constructor; explicit SHA256 and bounded work factor.
namespace Tqsim {
 public sealed class CryptoSession : IDisposable {
    public static long PeekManifestVersion(Stream input) {
        byte[] b=new byte[65536];int used=0;bool want=false;var state=new JsonReaderState();
        try {while(true){int n=input.Read(b,used,b.Length-used);bool final=n==0;used+=n;var r=new Utf8JsonReader(b.AsSpan(0,used),final,state);
            while(r.Read()){if(want){if(r.TokenType!=JsonTokenType.Number)throw new InvalidDataException("Invalid schema.");return r.GetInt64();}if(r.CurrentDepth==1&&r.TokenType==JsonTokenType.PropertyName&&r.ValueTextEquals("manifestVersion"))want=true;}
            int consumed=(int)r.BytesConsumed;state=r.CurrentState;Buffer.BlockCopy(b,consumed,b,0,used-consumed);used-=consumed;
            if(final||used==b.Length)throw new InvalidDataException("Missing schema or oversized metadata token.");
        }}finally{input.Position=0;}
    }
    public static byte[] Hex(string value) {if(value.Length%2!=0)throw new FormatException();byte[] b=new byte[value.Length/2];for(int i=0;i<b.Length;i++)b[i]=Convert.ToByte(value.Substring(i*2,2),16);return b;}
    public static byte[] RandomBytes(int count) {byte[] b=new byte[count];RandomNumberGenerator.Fill(b);return b;}
    public const int ChunkSize=4194304;
    readonly byte[] plain=new byte[ChunkSize], cipher=new byte[ChunkSize], tag=new byte[16], header=new byte[12];
    readonly byte[] prefix, id, macKey; readonly AesGcm aes;
    static byte[] PasswordBytes(SecureString secret) {
        IntPtr ptr=IntPtr.Zero;char[] chars=new char[secret.Length];
        try {ptr=Marshal.SecureStringToGlobalAllocUnicode(secret);Marshal.Copy(ptr,chars,0,chars.Length);return new UTF8Encoding(false,true).GetBytes(chars);}
        finally {Array.Clear(chars,0,chars.Length);if(ptr!=IntPtr.Zero)Marshal.ZeroFreeGlobalAllocUnicode(ptr);}
    }
    public static bool SameSecret(SecureString a,SecureString b) {byte[] x=PasswordBytes(a),y=PasswordBytes(b);try{return CryptographicOperations.FixedTimeEquals(x,y);}finally{CryptographicOperations.ZeroMemory(x);CryptographicOperations.ZeroMemory(y);}}
    public CryptoSession(SecureString password,byte[] salt,int iterations,byte[] noncePrefix,string operationId) {
        if(salt.Length!=32||noncePrefix.Length!=4||iterations<600000||iterations>2000000)throw new InvalidDataException("Unsupported encryption parameters.");
        byte[] pw=PasswordBytes(password),master=null,key=null;
        try {
            using(var kdf=new Rfc2898DeriveBytes(pw,salt,iterations,HashAlgorithmName.SHA256))master=kdf.GetBytes(32);
            using(var h=new HMACSHA256(master)) {key=h.ComputeHash(Encoding.UTF8.GetBytes("Tqsim-GCM-v1 encryption"));macKey=h.ComputeHash(Encoding.UTF8.GetBytes("Tqsim-GCM-v1 manifest"));}
#pragma warning disable SYSLIB0053
            aes=new AesGcm(key);
#pragma warning restore SYSLIB0053
            prefix=(byte[])noncePrefix.Clone();id=new Guid(operationId).ToByteArray();
        } finally {CryptographicOperations.ZeroMemory(pw);if(master!=null)CryptographicOperations.ZeroMemory(master);if(key!=null)CryptographicOperations.ZeroMemory(key);}
    }
    public byte[] ManifestMAC(byte[] data) {using(var h=new HMACSHA256(macKey))return h.ComputeHash(data);}
    public bool VerifyMAC(byte[] data,byte[] expected) {byte[] actual=ManifestMAC(data);try{return CryptographicOperations.FixedTimeEquals(actual,expected);}finally{CryptographicOperations.ZeroMemory(actual);}}
    public static byte[] Nonce(byte[] prefix,ulong ordinal) {
        if(prefix.Length!=4||ordinal>=uint.MaxValue)throw new InvalidDataException("Encryption nonce limit reached.");
        byte[] n=new byte[12];Buffer.BlockCopy(prefix,0,n,0,4);for(int i=0;i<8;i++)n[11-i]=(byte)(ordinal>>(i*8));return n;
    }
    byte[] AAD(long part,ulong ordinal,int length,long total,long partSize) {
        using(var ms=new MemoryStream())using(var w=new BinaryWriter(ms,Encoding.UTF8,true)) {w.Write(Encoding.ASCII.GetBytes("Tqsim-GCM-v1\0"));w.Write(id);w.Write((ulong)part);w.Write(ordinal);w.Write((uint)length);w.Write(total);w.Write(partSize);w.Flush();return ms.ToArray();}
    }
    static void ReadExactly(Stream s,byte[] b,int count) {int done=0;while(done<count){int n=s.Read(b,done,count-done);if(n==0)throw new InvalidDataException("Encrypted record is truncated.");done+=n;}}
    public void WriteRecord(Stream input,Stream output,int count,long part,ulong ordinal,long total,long partSize,IncrementalHash whole,IncrementalHash partHash) {
        if(count<1||count>ChunkSize)throw new InvalidDataException("Invalid record length.");
        ReadExactly(input,plain,count);whole.AppendData(plain,0,count);
        byte[] n=Nonce(prefix,ordinal);aes.Encrypt(n,plain.AsSpan(0,count),cipher.AsSpan(0,count),tag,AAD(part,ordinal,count,total,partSize));
        Buffer.BlockCopy(BitConverter.GetBytes((uint)count),0,header,0,4);Buffer.BlockCopy(BitConverter.GetBytes(ordinal),0,header,4,8);
        output.Write(header,0,12);output.Write(cipher,0,count);output.Write(tag,0,16);
        partHash.AppendData(header);partHash.AppendData(cipher,0,count);partHash.AppendData(tag);
    }
    public int ReadRecord(Stream input,Stream output,long remaining,long part,ulong ordinal,long total,long partSize,IncrementalHash whole,IncrementalHash partHash) {
        if(remaining<29)throw new InvalidDataException("Invalid encrypted record boundary.");
        ReadExactly(input,header,12);uint length=BitConverter.ToUInt32(header,0);
        if(length<1||length>ChunkSize||length+28L>remaining||BitConverter.ToUInt64(header,4)!=ordinal)throw new InvalidDataException("Invalid encrypted record order or length.");
        int count=(int)length;ReadExactly(input,cipher,count);ReadExactly(input,tag,16);
        partHash.AppendData(header);partHash.AppendData(cipher,0,count);partHash.AppendData(tag);
        aes.Decrypt(Nonce(prefix,ordinal),cipher.AsSpan(0,count),tag,plain.AsSpan(0,count),AAD(part,ordinal,count,total,partSize));
        whole.AppendData(plain,0,count);if(output!=null)output.Write(plain,0,count);return count;
    }
    public void Dispose() {aes.Dispose();CryptographicOperations.ZeroMemory(plain);CryptographicOperations.ZeroMemory(cipher);CryptographicOperations.ZeroMemory(macKey);CryptographicOperations.ZeroMemory(tag);}
 }
}
