# Bulk RNA-seq / 转录组分析 Harness

> 历史数据：12 个 session。
> 最高频问题：ORA DEG 定义与 plan.md 阈值不一致、stale output files。

---

## 标准流程

```
1. 数据准备（counts matrix / TPM / FPKM 确认）
2. QC（PCA、样本相关性热图、outlier 检测）
3. 差异分析（DESeq2 / limma-voom / edgeR）
4. 可视化（火山图、热图、MA plot）
5. GO/KEGG 富集（ORA / GSEA）
6. [可选] GSVA / ssGSEA
7. [可选] 免疫浸润分析（IOBR / CIBERSORT）
8. [可选] WGCNA 共表达网络
```

---

## 关键检查点

### 输入数据类型（P0）
- DESeq2 **必须** 用 raw counts — 检查矩阵中是否有小数（有小数 = 不是 raw counts）
- TPM/FPKM 用于可视化和 GSVA，**不可** 用于 DESeq2/edgeR 输入
- 如果数据来自 GEO，确认下载的是 counts 而非 normalized values

### DEG 阈值一致性（P1 — 高频历史问题）
- DEG 过滤的 |log2FC| 和 padj 阈值 **必须** 从 plan.md 固定参数中读取
- 火山图的标注线 **必须** 与 DEG 过滤阈值一致
- ORA 输入的 gene list **必须** 用同一套阈值生成
- 禁止在不同步骤使用不同的阈值定义

### 对照组方向
- 对照组 **必须** 在 DESeq2 design formula 的 reference level
- log2FC > 0 = Treatment 中上调，必须在图表标注中明确
- 如果有多个对比组，每组的方向必须单独确认

### 富集分析
- ORA 的 background gene set：默认使用全基因组，非"表达基因组"
- GSEA 的 ranked list：用 -log10(pvalue) * sign(log2FC)，不是只用 log2FC
- 数据库版本记录到执行日志

---

## 已知陷阱

| 陷阱 | 防护措施 |
|------|---------|
| ORA DEG 阈值与火山图不一致 | 统一从 plan.md 参数变量读取 |
| 修改脚本后未重跑下游步骤 | 每次修改后检查 output 时间戳 |
| log2FC 方向搞反 | 检查 DESeq2 results() 的 contrast 参数 |
| TPM 当 counts 喂给 DESeq2 | 检查矩阵是否有小数 |
| 忘记多重比较校正 | 确认 padj 列存在且使用了 BH 校正 |
| GEO 下载的数据已被 normalized | 检查 GEO 页面的 Data Processing 说明 |
