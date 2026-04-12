# QC 断言测试项目

## 四、执行步骤

### Step 1: 数据准备
- 输出：results/data.csv
- QC: sample_total == 12
- QC: gene_count > 5
- QC: results/data.csv exists

### Step 2: 差异分析
- 输出：results/deg.csv
- QC: deg_total ~ 1-100
- QC: deg_up > 0
- QC: mapping_rate >= 0.8
- QC: na_ratio < 0.05
- QC: bad_rate <= 0.1

## 五、交付清单
| 序号 | 文件名 | 格式 | 说明 |
|------|--------|------|------|
| 1 | data.csv | CSV | 数据 |
| 2 | deg.csv | CSV | DEG |
