# JPEG quality: the snapshot is encoded with JPEG_QUALITY of hack.ini. The quality is estimated
# from the luminance quantization table (IJG scaling of the standard table). Read only.
# JPEG 画質: スナップショットの量子化テーブルから推定した画質が JPEG_QUALITY と同じか（読み出しのみ）

want=$(ini_get JPEG_QUALITY)
if [ -z "$want" ]; then
  skip "jpeg: quality" "JPEG_QUALITY is not set"
  return 0
fi

# jpeg_quality : estimated quality from the first 8-bit luminance table (DQT) on stdin
jpeg_quality() {
  od -An -v -tu1 | awk '
  BEGIN {
    split("16 11 10 16 24 40 51 61 12 12 14 19 26 58 60 55 14 13 16 24 40 57 69 56 14 17 22 29 51 87 80 62 " \
          "18 22 37 56 68 109 103 77 24 35 55 64 81 104 113 92 49 64 78 87 103 121 120 101 72 92 95 98 112 100 103 99", std);
    for(i = 1; i <= 64; i++) stdsum += std[i];
  }
  { for(i = 1; i <= NF; i++) b[n++] = $i; }
  END {
    p = 2;
    while(p + 4 <= n && b[p] == 255) {
      m = b[p + 1]; len = b[p + 2] * 256 + b[p + 3];
      if(m == 218) break; # SOS
      if(m == 219) { # DQT
        q = p + 4;
        while(q < p + 2 + len) {
          id = b[q] % 16; prec = int(b[q] / 16); sum = 0;
          for(i = 1; i <= 64; i++) sum += b[q + i];
          if(id == 0 && prec == 0) {
            s = sum * 100 / stdsum;
            printf("%d\n", (s <= 100) ? (200 - s) / 2 + 0.5 : 5000 / s + 0.5);
            exit;
          }
          q += 1 + 64 * (prec + 1);
        }
      }
      p += 2 + len;
    }
  }'
}

got=$(http /cgi-bin/get_jpeg.cgi | jpeg_quality)
if [ -z "$got" ]; then
  fail "jpeg: quality" "no luminance table in the snapshot"
elif [ $((got - want)) -le 2 ] && [ $((want - got)) -le 2 ]; then
  pass "jpeg: quality (JPEG_QUALITY=$want, estimated $got)"
else
  fail "jpeg: quality" "JPEG_QUALITY=$want, estimated $got from the snapshot"
fi
