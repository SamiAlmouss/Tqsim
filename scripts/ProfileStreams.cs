// Developer-only instrumentation. Never included in release archives.
using System;
using System.IO;
using System.Collections.Generic;
using System.Diagnostics;
using System.Security.Cryptography;
public static class TqsimProfile {
    public static long ReadBytes, WrittenBytes, ReadCalls, WriteCalls, HashCalls;
    public static Dictionary<string,double> Seconds = new Dictionary<string,double>();
    public static Dictionary<string,long> BytesByPath = new Dictionary<string,long>();
    public static Dictionary<string,double> ReadSecondsByPath = new Dictionary<string,double>();
    public static void Reset() { ReadBytes=WrittenBytes=ReadCalls=WriteCalls=HashCalls=0; Seconds.Clear(); BytesByPath.Clear();ReadSecondsByPath.Clear(); }
    public static void Add(string key,long ticks) {double old;Seconds.TryGetValue(key,out old);Seconds[key]=old+(double)ticks/Stopwatch.Frequency;}
    public static void Read(string path,int count,long ticks) {ReadBytes+=count;ReadCalls++;long old;BytesByPath.TryGetValue(path,out old);BytesByPath[path]=old+count;double sec;ReadSecondsByPath.TryGetValue(path,out sec);ReadSecondsByPath[path]=sec+(double)ticks/Stopwatch.Frequency;Add("read",ticks);}
    public static void Append(IncrementalHash hash,byte[] buffer,int offset,int count) {long t=Stopwatch.GetTimestamp();hash.AppendData(buffer,offset,count);HashCalls++;Add("hashCPU",Stopwatch.GetTimestamp()-t);}
    public static byte[] Digest(HashAlgorithm hash,Stream stream) {double before=Seconds.ContainsKey("read")?Seconds["read"]:0;long t=Stopwatch.GetTimestamp();byte[] b=hash.ComputeHash(stream);double read=(Seconds.ContainsKey("read")?Seconds["read"]:0)-before;Add("hashIncludingRead",Stopwatch.GetTimestamp()-t);Add("hashCPU",(long)((double)(Stopwatch.GetTimestamp()-t)-read*Stopwatch.Frequency));HashCalls++;return b;}
    public static void Move(string a,string b) {long t=Stopwatch.GetTimestamp();try{File.Move(a,b);}finally{Add("publication",Stopwatch.GetTimestamp()-t);}}
    public static void Move(string a,string b,bool overwrite) {long t=Stopwatch.GetTimestamp();try{File.Move(a,b,overwrite);}finally{Add("publication",Stopwatch.GetTimestamp()-t);}}
    public static void Replace(string a,string b,string c) {long t=Stopwatch.GetTimestamp();try{File.Replace(a,b,c);}finally{Add("publication",Stopwatch.GetTimestamp()-t);}}
    public static void Delete(string path) {long t=Stopwatch.GetTimestamp();try{File.Delete(path);}finally{Add("deleteSystemCall",Stopwatch.GetTimestamp()-t);}}
    public static void WriteAllText(string path,string text) {long t=Stopwatch.GetTimestamp();try{File.WriteAllText(path,text);}finally{Add("manifestCreation",Stopwatch.GetTimestamp()-t);}}
}
public sealed class TqsimProfileStream : FileStream {
    public TqsimProfileStream(string path,FileMode mode,FileAccess access):base(path,mode,access,FileShare.Read,4096,FileOptions.SequentialScan) {}
    public override int Read(byte[] b,int o,int c) {long t=Stopwatch.GetTimestamp();int n=base.Read(b,o,c);TqsimProfile.Read(Name,n,Stopwatch.GetTimestamp()-t);return n;}
    public override void Write(byte[] b,int o,int c) {long t=Stopwatch.GetTimestamp();base.Write(b,o,c);TqsimProfile.WrittenBytes+=c;TqsimProfile.WriteCalls++;TqsimProfile.Add("write",Stopwatch.GetTimestamp()-t);}
    public override void Flush(bool disk) {long t=Stopwatch.GetTimestamp();base.Flush(disk);TqsimProfile.Add("flush",Stopwatch.GetTimestamp()-t);}
}
