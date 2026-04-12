# 交付标准

---

## 交付包目录结构

```
[项目名称]_分析结果/
├── 01_分析报告/
│   ├── [项目名称]_分析报告.docx
│   └── [项目名称]_分析报告.pdf（可选）
├── 02_分析结果/
│   ├── 01_数据预处理/
│   ├── 02_差异分析/
│   ├── 03_富集分析/
│   └── ...（按 plan.md 步骤编号）
├── 03_图表/
│   ├── Fig1_xxx.pdf
│   ├── Fig1_xxx.png
│   └── ...
├── 04_补充表格/
│   ├── Table_S1_xxx.xlsx
│   └── ...
├── 05_分析脚本/
│   ├── 01_data_prep.R
│   └── ...
└── README.txt（文件说明）
```

---

## 命名规范

```yaml
language: 中文（文件夹名和报告标题） + 英文（脚本名和变量名）
folder_prefix: 两位数字编号（01_, 02_, ...）
figure_prefix: "Fig" + 序号 + "_" + 简短英文描述（如 Fig1_volcano_plot）
table_prefix: "Table_S" + 序号 + "_" + 简短英文描述
no_spaces: 文件名中用下划线替代空格
no_special_chars: 避免 Windows 不兼容字符（\ / : * ? " < > |）
```

---

## 打包与传输

| 项目 | 要求 |
|------|------|
| 格式 | ZIP（标准压缩，非 7z / tar.gz） |
| 编码 | UTF-8（中文文件名 Windows 可正常显示） |
| 校验 | 生成 MD5 校验文件 |
| 传输 | Tailscale → Windows 桌面（/transfer skill） |
| 测试 | 打包后在 Windows 下解压验证文件名和内容 |

推荐直接使用 `bash harness/delivery/package.sh <delivery_dir> [zip_path]` 执行标准打包流程。
