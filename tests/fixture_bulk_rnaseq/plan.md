# 心衰转录组差异分析

## 一、项目背景
- 物种/样本：人（Homo sapiens）
- 实验设计：HF组 6例 vs Control组 6例，共12个样本
- 数据来源：GSE12345（模拟）
- 关键生物学问题：筛选心衰相关差异基因并进行功能富集

## 二、成功标准
1. [x] 产出文件清单完整
2. [x] 数值一致性
3. [x] 图表标准
4. [x] 方法合理性
5. [x] 交付完整性

## 三、固定参数
- DEG 阈值：|log2FC| > 1, padj < 0.05
- 富集分析：ORA，GO-BP + KEGG
- 比较组定义：HF vs Control
- 物种注释库：org.Hs.eg.db

## 四、执行步骤

### Step 1: 数据准备
- 输入：raw counts matrix
- 操作：DESeq2 归一化
- 输出：results/normalized_counts.csv
- QC检查点：样本数=12，基因数>10000
- QC: sample_total == 12
- QC: gene_total > 2
- QC: results/normalized_counts.csv exists

### Step 2: 差异分析
- 输入：normalized counts
- 操作：DESeq2 DEG
- 输出：results/deg_results.csv
- QC检查点：DEG数量合理（50-5000）
- QC: deg_up > 0
- QC: deg_down > 0
- QC: results/deg_results.csv exists

### Step 3: 富集分析
- 输入：DEG list
- 操作：clusterProfiler ORA
- 输出：results/enrichment_go.csv, results/enrichment_kegg.csv
- QC检查点：显著通路数>0
- QC: go_sig_terms > 0
- QC: kegg_sig_terms > 0

## 五、交付清单
| 序号 | 文件名 | 格式 | 说明 |
|------|--------|------|------|
| 1 | deg_results.csv | CSV | 差异分析结果 |
| 2 | enrichment_go.csv | CSV | GO富集结果 |
| 3 | enrichment_kegg.csv | CSV | KEGG富集结果 |
| 4 | Fig1_volcano.png | PNG | 火山图 |
| 5 | Fig2_heatmap.png | PNG | 差异基因热图 |

## 六、风险与限制
- 模拟数据，仅用于 harness 脚本回归测试
