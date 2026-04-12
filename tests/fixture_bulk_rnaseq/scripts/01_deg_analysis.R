# 差异分析脚本（fixture）
library(DESeq2)
# 标准 DESeq2 分析流程
dds <- DESeqDataSetFromMatrix(countData = counts, colData = coldata, design = ~group)
dds <- DESeq(dds)
res <- results(dds, contrast = c("group", "HF", "Control"))
