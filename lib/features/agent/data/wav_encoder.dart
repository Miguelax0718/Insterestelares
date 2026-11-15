import 'dart:typed_data';

/// Wraps raw 16-bit signed little-endian PCM bytes into a standard RIFF/WAV
/// container so captured audio works identically across web, mobile, and desktop.
Uint8List buildWavBytes(
  Uint8List pcmBytes, {
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final blockAlign = channels * (bitsPerSample ~/ 8);
  final dataSize = pcmBytes.lengthInBytes;
  final fileSizeMinus8 = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  // "RIFF"
  buffer.setUint8(0, 0x52);
  buffer.setUint8(1, 0x49);
  buffer.setUint8(2, 0x46);
  buffer.setUint8(3, 0x46);
  buffer.setUint32(4, fileSizeMinus8, Endian.little);
  // "WAVE"
  buffer.setUint8(8, 0x57);
  buffer.setUint8(9, 0x41);
  buffer.setUint8(10, 0x56);
  buffer.setUint8(11, 0x45);
  // "fmt "
  buffer.setUint8(12, 0x66);
  buffer.setUint8(13, 0x6D);
  buffer.setUint8(14, 0x74);
  buffer.setUint8(15, 0x20);
  buffer.setUint32(16, 16, Endian.little); // PCM subchunk size
  buffer.setUint16(20, 1, Endian.little); // PCM format
  buffer.setUint16(22, channels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, blockAlign, Endian.little);
  buffer.setUint16(34, bitsPerSample, Endian.little);
  // "data"
  buffer.setUint8(36, 0x64);
  buffer.setUint8(37, 0x61);
  buffer.setUint8(38, 0x74);
  buffer.setUint8(39, 0x61);
  buffer.setUint32(40, dataSize, Endian.little);

  final out = buffer.buffer.asUint8List();
  out.setRange(44, 44 + dataSize, pcmBytes);
  return out;
}
