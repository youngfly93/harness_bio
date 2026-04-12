### Step 1: 数据准备
- 输入：raw counts matrix
- 操作：读取计数矩阵，确认为 raw counts（无小数），DESeq2 归一化
- 输出：results/normalized_counts.csv
- QC: sample_total == {{SAMPLE_TOTAL}}
- QC: gene_count > 10000
- QC: results/normalized_counts.csv exists

### Step 2: 质量控制
- 输入：normalized counts
- 操作：PCA、样本相关性热图、outlier 检测
- 输出：figures/Fig1_PCA.png, figures/Fig2_sample_correlation.png
- QC: figures/Fig1_PCA.png exists
- QC: figures/Fig2_sample_correlation.png exists

### Step 3: 差异分析
- 输入：raw counts（DESeq2 输入必须是 raw counts）
- 操作：DESeq2 DEG，contrast = {{GROUP_TREATMENT}} vs {{GROUP_CONTROL}}，|log2FC| > {{LOG2FC_THRESHOLD}}，padj < {{PADJ_THRESHOLD}}
- 输出：results/deg_results.csv, figures/Fig3_volcano.png, figures/Fig4_heatmap.png
- QC: deg_total ~ 50-5000
- QC: deg_up > 0
- QC: deg_down > 0
- QC: results/deg_results.csv exists

### Step 4: GO/KEGG 富集分析
- 输入：DEG gene list（与 Step 3 阈值一致）
- 操作：clusterProfiler ORA，GO-BP + KEGG，background = 全基因组
- 输出：results/enrichment_go.csv, results/enrichment_kegg.csv, figures/Fig5_go_dotplot.png, figures/Fig6_kegg_dotplot.png
- QC: go_sig_terms > 0
- QC: results/enrichment_go.csv exists
- QC: results/enrichment_kegg.csv exists

### Step 5: 报告生成
- 输入：所有分析结果
- 操作：生成 Word 分析报告，数值程序化嵌入
- 输出：reports/分析报告.docx
- QC: reports/分析报告.docx exists
