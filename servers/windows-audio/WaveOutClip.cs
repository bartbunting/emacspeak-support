// Copyright (C) 2026 Bart Bunting
// SPDX-License-Identifier: GPL-2.0-or-later
//
// This file is not part of GNU Emacs, but the same permissions apply.
// See the file COPYING in this distribution.

using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class NativeClipWaveOut
{
    internal const uint WaveMapper = 0xffffffff;
    internal const uint CallbackEvent = 0x00050000;
    internal const uint HeaderDone = 0x00000001;

    [StructLayout(LayoutKind.Sequential, Pack = 2)]
    internal struct WaveFormat
    {
        internal ushort FormatTag;
        internal ushort Channels;
        internal uint SamplesPerSecond;
        internal uint AverageBytesPerSecond;
        internal ushort BlockAlign;
        internal ushort BitsPerSample;
        internal ushort ExtraSize;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct WaveHeader
    {
        internal IntPtr Data;
        internal uint BufferLength;
        internal uint BytesRecorded;
        internal UIntPtr User;
        internal uint Flags;
        internal uint Loops;
        internal IntPtr Next;
        internal UIntPtr Reserved;
    }

    [DllImport("winmm.dll", CallingConvention = CallingConvention.Winapi)]
    internal static extern int waveOutOpen(out IntPtr handle, uint device,
        ref WaveFormat format, IntPtr callback, IntPtr instance, uint flags);

    [DllImport("winmm.dll", CallingConvention = CallingConvention.Winapi)]
    internal static extern int waveOutPrepareHeader(IntPtr handle,
        IntPtr header, uint headerSize);

    [DllImport("winmm.dll", CallingConvention = CallingConvention.Winapi)]
    internal static extern int waveOutUnprepareHeader(IntPtr handle,
        IntPtr header, uint headerSize);

    [DllImport("winmm.dll", CallingConvention = CallingConvention.Winapi)]
    internal static extern int waveOutWrite(IntPtr handle, IntPtr header,
        uint headerSize);

    [DllImport("winmm.dll", CallingConvention = CallingConvention.Winapi)]
    internal static extern int waveOutClose(IntPtr handle);
}

internal sealed class WaveOutClip
{
    private readonly byte[] wave;
    private NativeClipWaveOut.WaveFormat format;
    private int dataOffset;
    private int dataLength;

    private WaveOutClip(byte[] wave)
    {
        this.wave = wave;
        ParseWave();
    }

    internal static void Play(byte[] wave)
    {
        WaveOutClip clip = new WaveOutClip(wave);
        Thread thread = new Thread(clip.Run);
        thread.IsBackground = true;
        thread.Name = "Emacspeak auditory icon";
        thread.Start();
    }

    private void ParseWave()
    {
        bool foundFormat = false;
        bool foundData = false;
        using (MemoryStream stream = new MemoryStream(wave, false))
        using (BinaryReader reader = new BinaryReader(stream))
        {
            if (ReadId(reader) != "RIFF" || reader.ReadUInt32() > wave.Length ||
                ReadId(reader) != "WAVE")
            {
                throw new InvalidDataException("Unsupported WAV file");
            }

            while (stream.Position + 8 <= stream.Length)
            {
                string id = ReadId(reader);
                uint chunkLength = reader.ReadUInt32();
                long chunkStart = stream.Position;
                long next = chunkStart + chunkLength + (chunkLength & 1);
                if (next > stream.Length)
                {
                    throw new InvalidDataException("Truncated WAV file");
                }

                if (id == "fmt ")
                {
                    if (chunkLength < 16)
                    {
                        throw new InvalidDataException("Invalid WAV format");
                    }
                    format.FormatTag = reader.ReadUInt16();
                    format.Channels = reader.ReadUInt16();
                    format.SamplesPerSecond = reader.ReadUInt32();
                    format.AverageBytesPerSecond = reader.ReadUInt32();
                    format.BlockAlign = reader.ReadUInt16();
                    format.BitsPerSample = reader.ReadUInt16();
                    format.ExtraSize = 0;
                    foundFormat = true;
                }
                else if (id == "data")
                {
                    dataOffset = checked((int)chunkStart);
                    dataLength = checked((int)chunkLength);
                    foundData = true;
                }
                stream.Position = next;
            }
        }

        if (!foundFormat || !foundData || format.FormatTag != 1 ||
            dataLength == 0)
        {
            throw new InvalidDataException("WAV must contain PCM audio");
        }
    }

    private static string ReadId(BinaryReader reader)
    {
        byte[] id = reader.ReadBytes(4);
        if (id.Length != 4)
        {
            throw new EndOfStreamException();
        }
        return Encoding.ASCII.GetString(id);
    }

    private void Run()
    {
        IntPtr handle = IntPtr.Zero;
        IntPtr data = IntPtr.Zero;
        IntPtr header = IntPtr.Zero;
        bool prepared = false;
        uint headerSize =
            (uint)Marshal.SizeOf(typeof(NativeClipWaveOut.WaveHeader));

        using (AutoResetEvent completed = new AutoResetEvent(false))
        {
            try
            {
                Check(NativeClipWaveOut.waveOutOpen(out handle,
                    NativeClipWaveOut.WaveMapper, ref format,
                    completed.SafeWaitHandle.DangerousGetHandle(), IntPtr.Zero,
                    NativeClipWaveOut.CallbackEvent), "waveOutOpen");

                data = Marshal.AllocHGlobal(dataLength);
                Marshal.Copy(wave, dataOffset, data, dataLength);
                NativeClipWaveOut.WaveHeader value =
                    new NativeClipWaveOut.WaveHeader();
                value.Data = data;
                value.BufferLength = (uint)dataLength;
                header = Marshal.AllocHGlobal((int)headerSize);
                Marshal.StructureToPtr(value, header, false);

                Check(NativeClipWaveOut.waveOutPrepareHeader(handle, header,
                    headerSize), "waveOutPrepareHeader");
                prepared = true;
                Check(NativeClipWaveOut.waveOutWrite(handle, header,
                    headerSize), "waveOutWrite");

                while (true)
                {
                    completed.WaitOne();
                    value = (NativeClipWaveOut.WaveHeader)
                        Marshal.PtrToStructure(header,
                            typeof(NativeClipWaveOut.WaveHeader));
                    if ((value.Flags & NativeClipWaveOut.HeaderDone) != 0)
                    {
                        break;
                    }
                }
            }
            catch (Exception error)
            {
                Console.Error.WriteLine(error.Message);
            }
            finally
            {
                if (prepared)
                {
                    NativeClipWaveOut.waveOutUnprepareHeader(handle, header,
                        headerSize);
                }
                if (handle != IntPtr.Zero)
                {
                    NativeClipWaveOut.waveOutClose(handle);
                }
                if (header != IntPtr.Zero)
                {
                    Marshal.FreeHGlobal(header);
                }
                if (data != IntPtr.Zero)
                {
                    Marshal.FreeHGlobal(data);
                }
            }
        }
    }

    private static void Check(int result, string operation)
    {
        if (result != 0)
        {
            throw new InvalidOperationException(
                operation + " failed with Windows multimedia error " + result);
        }
    }
}
