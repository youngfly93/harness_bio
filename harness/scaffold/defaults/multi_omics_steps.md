### Step 1: 各组学独立分析
- 输入：各组学原始数据
- 操作：按各自标准流程独立分析（参照对应单组学 Harness）
- 输出：results/omics_1_results/, results/omics_2_results/
- QC: results/omics_1_results/ exists
- QC: results/omics_2_results/ exists

### Step 2: 样本 ID 匹配验证
- 输入：各组学样本列表
- 操作：交叉比对样本 ID，输出交集/差集报告
- 输出：results/sample_id_matching.csv
- QC: matched_samples > 0
- QC: results/sample_id_matching.csv exists

### Step 3: 数据标准化与对齐
- 输入：匹配后的各组学数据
- 操作：各组学使用各自归一化方法（不混用），按共同样本对齐
- 输出：results/aligned_data.rds
- QC: results/aligned_data.rds exists

### Step 4: 相关性与整合分析
- 输入：标准化对齐后的多组学数据
- 操作：Mantel test / Procrustes / MOFA（permutations >= 999）
- 输出：results/correlation_results.csv, figures/Fig1_integration.png
- QC: results/correlation_results.csv exists

### Step 5: 联合可视化
- 输入：整合分析结果
- 操作：联合热图、桑基图、网络图
- 输出：figures/Fig2_joint_heatmap.png, figures/Fig3_network.png
- QC: figures/Fig2_joint_heatmap.png exists

### Step 6: 报告生成
- 输入：所有分析结果
- 操作：生成 Word 分析报告，数值程序化嵌入
- 输出：reports/分析报告.docx
- QC: reports/分析报告.docx exists
