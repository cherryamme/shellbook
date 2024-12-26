### Step1 sampling data build (Use send to qsub)

seqtk=/home/long_read/long_read/software/seqtk
samplelist=/samle.list

datadir=LRS_THAL
analysisdir=/workdir/THAL/LRS_THAL_V1.0.11

outdir=

while read barcode batch sample; do
	echo "Process $barcode;$batch;$sample"
	for num in 350; do
		mkdir -p ${outdir}/analysis/${num}/data
		if ls $analysisdir/${batch}/output/*/03_indexfq/${sample} >/dev/null 2>&1; then
			echo "start process $barcode;$batch;$sample  $num"
			mkdir -p ${outdir}/analysis/${num}/output/${barcode}/{01_filter,02_spliter,03_indexfq/${sample}_1,03_indexfq/${sample}_2,03_indexfq/${sample}_3}
			${seqtk} sample -s1 $analysisdir/${batch}/output/*/03_indexfq/${sample}/alpha*fq.gz ${num} | gzip -c >${outdir}/analysis/${num}/data/alpha_${sample}_1.fq.gz &
			${seqtk} sample -s2 $analysisdir/${batch}/output/*/03_indexfq/${sample}/alpha*fq.gz ${num} | gzip -c >${outdir}/analysis/${num}/data/alpha_${sample}_2.fq.gz &
			${seqtk} sample -s3 $analysisdir/${batch}/output/*/03_indexfq/${sample}/alpha*fq.gz ${num} | gzip -c >${outdir}/analysis/${num}/data/alpha_${sample}_3.fq.gz &

			${seqtk} sample -s1 $analysisdir/${batch}/output/*/03_indexfq/${sample}/beta*fq.gz ${num} | gzip -c >${outdir}/analysis/${num}/data/beta_${sample}_1.fq.gz &
			${seqtk} sample -s2 $analysisdir/${batch}/output/*/03_indexfq/${sample}/beta*fq.gz ${num} | gzip -c >${outdir}/analysis/${num}/data/beta_${sample}_2.fq.gz &
			${seqtk} sample -s3 $analysisdir/${batch}/output/*/03_indexfq/${sample}/beta*fq.gz ${num} | gzip -c >${outdir}/analysis/${num}/data/beta_${sample}_3.fq.gz &
			wait
			ln -sf ${outdir}/analysis/${num}/data/{alpha,beta}_${sample}_1.fq.gz ${outdir}/analysis/${num}/output/${barcode}/03_indexfq/${sample}_1/
			ln -sf ${outdir}/analysis/${num}/data/{alpha,beta}_${sample}_2.fq.gz ${outdir}/analysis/${num}/output/${barcode}/03_indexfq/${sample}_2/
			ln -sf ${outdir}/analysis/${num}/data/{alpha,beta}_${sample}_3.fq.gz ${outdir}/analysis/${num}/output/${barcode}/03_indexfq/${sample}_3/
		else
			echo "$barcode;$batch;$sample has no 03_indexfq"
		fi
	done
done <$samplelist

###

### Step2  sampling config build

samplelist=/samle.list
rg=software/miniconda3/bin/rg
datadir=LRS_THAL
analysisdir=/workdir/THAL/LRS_THAL_V1.0.11

outdir=
mkdir -p $outdir/config

while read barcode batch sample; do
	# echo "Process $barcode;$batch;$sample"
	config_file="$datadir/$batch/config/SVgolden.info"
	# 使用 awk 处理文件
	awk -v sample="$sample" '
    BEGIN { FS=OFS="\t" }
    $0 ~ sample {
        # 保存第一列
        first_col = $1
        # 输出三行，第一列末尾加上 _1, _2, _3
        print first_col "_1", $2 , $3 , $4, $5, $6
        print first_col "_2", $2 , $3 , $4, $5, $6
        print first_col "_3", $2 , $3 , $4, $5, $6
    }
    ' "$config_file"
done <$samplelist >$outdir/config/SVgolden.info

while read barcode batch sample; do
	# echo "Process $barcode;$batch;$sample"
	config_file="$datadir/$batch/config/SNVgolden.info"
	# 使用 awk 处理文件
	awk -v sample="$sample" '
    BEGIN { FS=OFS="\t" }
    $0 ~ sample {
        # 保存第一列
        first_col = $1
        # 输出三行，第一列末尾加上 _1, _2, _3
        print first_col "_1", $2 , $3 , $4
        print first_col "_2", $2 , $3 , $4
        print first_col "_3", $2 , $3 , $4
    }
    ' "$config_file"
done <$samplelist >$outdir/config/SNVgolden.info

echo -e "sysID\tBarcode\tsample\tIndex\tnote" >$outdir/config/info.txt
while read barcode batch sample; do
	# echo "Process $barcode;$batch;$sample"
	config_file="$datadir/$batch/config/info.txt"
	# 使用 awk 处理文件
	awk -v sample="$sample" -v barcode="$barcode" '
    BEGIN { FS=OFS="\t" }
    $3 ~ sample {
        # 保存第一列
        # 输出三行，第一列末尾加上 _1, _2, _3
        print $1, barcode, $3 "_1", $4, $5
        print $1, barcode, $3 "_2", $4, $5
        print $1, barcode, $3 "_3", $4, $5

    }
    ' "$config_file"
done <$samplelist >>$outdir/config/info.txt

echo -e "sysID\tSlide\tBarcode\tfq1_path\tfq2_path\tfq1_stat\tfq2_stat\tsummary_report\tbarcode_stat" >$outdir/config/sequence.list
while read barcode batch sample; do
	# echo "Process $barcode;$batch;$sample"
	# 使用awk和sort去重并生成所需的行
	awk -F'\t' '!seen[$1]++ { 
    slide = $2
    barcode = $1
    sysID = slide "-pos1213-3"
    fq1_path = "LRS_THAL/p601/p601-pos1213-3"
    print "v" "\t" "v" "\t" barcode "\t" fq1_path "\t\t\t\t" 
}'
done <$samplelist >>$outdir/config/sequence.list
###

### Step3  build spliter info

outdir=outdir

source_dir=output/2/

for num in {50,100,150,200,250,300}; do
	python /copy_sample_data.py $outdir/analysis/$num/output $outdir/config/info.txt $source_dir
done

###

### Step4  analysis sampling data
singularity exec -B /hwfsyt1/B2C_RD_S1/PROJECT/LRS,/dfsyt1/B2C_RD_S1/PROJECT/LRS home/long_read/LRS/pipeline/lrs_thal_1.0.11.sif prepare_input.py \
	-w 5 \
	--note \
	-q "qsub -terse -V -cwd -l vf=5G,p=2 -P B2C_RDC -q b2c_rd1.q" \
	--bind ,/hwfsyt1/B2C_RD_S1/PROJECT/LRS \
	--snvgolden /config/SNVgolden.info \
	--svgolden /config/SVgolden.info \
	--jobname \
	-i /config/sequence.list \
	-s /config/info.txt \
	-o output
# -q "qsub -terse -V -cwd -l vf=50G,p=10 -P B2C_RDC -q b2c_rd1.q" \
# run command
$output/input/runall.sh
###

### step5
echo this is step5
###

stepon step6
sleep 5
echo this is step6
stepoff step6

### step7
# Iter: jobid= 1 3 5 7 9
# Iter: jobid={1..10}
echo this is job $jobid

###
