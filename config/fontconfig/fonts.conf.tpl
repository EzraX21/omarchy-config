<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- 由 omarchy-config 生成：sans-serif / serif / monospace 全部优先 @FAMILY@
       （system-ui 无法通过 fontconfig 重映射，实测无效，故不写） -->
  <match target="pattern">
    <test name="family" qual="any"><string>sans-serif</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>@FAMILY@</string></edit>
  </match>
  <match target="pattern">
    <test name="family" qual="any"><string>serif</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>@FAMILY@</string></edit>
  </match>
  <match target="pattern">
    <test name="family" qual="any"><string>monospace</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>@FAMILY@</string></edit>
  </match>
  <!-- 缺字时回退中文字体 -->
  <alias>
    <family>@FAMILY@</family>
    <prefer><family>@FALLBACK_CJK@</family></prefer>
  </alias>
</fontconfig>
