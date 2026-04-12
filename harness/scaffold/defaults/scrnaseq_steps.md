### Step 1: 数据读取与 QC
- 输入：10X CellRanger 输出 / counts matrix
- 操作：Seurat CreateSeuratObject，过滤低质量细胞（nFeature、percent.mt）
- 输出：results/seurat_filtered.rds
- QC: cell_count_pre > 0
- QC: cell_count_post > 0
- QC: results/seurat_filtered.rds exists

### Step 2: 归一化与高变基因
- 输入：filtered Seurat object
- 操作：NormalizeData + FindVariableFeatures + ScaleData
- 输出：results/seurat_normalized.rds
- QC: hvg_count > 1000

### Step 3: 降维与聚类
- 输入：normalized Seurat object
- 操作：RunPCA → RunUMAP → FindNeighbors → FindClusters (resolution={{CLUSTER_RESOLUTION}})
- 输出：results/seurat_clustered.rds, figures/Fig1_UMAP_clusters.png
- QC: cluster_count > 1
- QC: figures/Fig1_UMAP_clusters.png exists

### Step 4: 细胞类型注释
- 输入：clustered Seurat object
- 操作：SingleR / 手动 marker 注释，展示每个 cluster 的 top5 marker
- 输出：results/cell_annotations.csv, figures/Fig2_UMAP_celltypes.png, figures/Fig3_marker_dotplot.png
- QC: annotation_count == {{EXPECTED_CELLTYPES}}
- QC: results/cell_annotations.csv exists
- QC: figures/Fig2_UMAP_celltypes.png exists

### Step 5: 差异表达
- 输入：annotated Seurat object
- 操作：FindMarkers / FindAllMarkers，|log2FC| > {{LOG2FC_THRESHOLD}}，padj < {{PADJ_THRESHOLD}}
- 输出：results/deg_results.csv
- QC: deg_total > 0
- QC: results/deg_results.csv exists

### Step 6: 富集分析
- 输入：DEG gene list
- 操作：clusterProfiler ORA / GSEA，GO-BP + KEGG
- 输出：results/enrichment_go.csv, results/enrichment_kegg.csv
- QC: results/enrichment_go.csv exists

### Step 7: 报告生成
- 输入：所有分析结果
- 操作：生成 Word 分析报告，数值程序化嵌入
- 输出：reports/分析报告.docx
- QC: reports/分析报告.docx exists
