#!/bin/bash

stage=4
stop_stage=4

config_path=$1
add_blank=$2
ge2e_ckpt_path=$3

# gen speaker embedding
if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    echo "Inferencing Model"
    python3 ${MAIN_ROOT}/paddlespeech/vector/exps/ge2e/inference.py \
        --input=~/Desktop/vctk_dataset2/VCTK-Corpus/wav48 \
        --output=dump/embed \
        --checkpoint_path=${ge2e_ckpt_path}
fi

# copy from tts3/preprocess
if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    # get durations from MFA's result
    echo "Generate durations.txt from MFA results ..."
    python3 ${MAIN_ROOT}/utils/gen_duration_from_textgrid.py \
        --inputdir=~/Desktop/vctk_dataset2/VCTK-Corpus/vctk_textgrid_arpa \
        --output durations.txt \
        --config=${config_path}
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    # extract features
    echo "Extract features ..."
    python3 ${BIN_DIR}/preprocess.py \
        --dataset=aishell3 \
        --rootdir=~/Desktop/vctk_dataset2/VCTK-Corpus/ \
        --dumpdir=dump \
        --dur-file=durations.txt \
        --config=${config_path} \
        --num-cpu=20 \
        --cut-sil=True \
        --spk_emb_dir=dump/embed
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    # get features' stats(mean and std)
    echo "Get features' stats ..."
    python3 ${MAIN_ROOT}/utils/compute_statistics.py \
        --metadata=dump/train/raw/metadata.jsonl \
        --field-name="feats"
fi

if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
    # normalize and covert phone/speaker to id, dev and test should use train's stats
    echo "Normalize ..."
    python3 ${BIN_DIR}/normalize.py \
        --metadata=dump/train/raw/metadata.jsonl \
        --dumpdir=dump/train/norm \
        --feats-stats=dump/train/feats_stats.npy \
        --phones-dict=dump/phone_id_map.txt \
        --speaker-dict=dump/speaker_id_map.txt \
        --add-blank=${add_blank} \
        --skip-wav-copy

    python3 ${BIN_DIR}/normalize.py \
        --metadata=dump/dev/raw/metadata.jsonl \
        --dumpdir=dump/dev/norm \
        --feats-stats=dump/train/feats_stats.npy \
        --phones-dict=dump/phone_id_map.txt \
        --speaker-dict=dump/speaker_id_map.txt \
        --add-blank=${add_blank} \
        --skip-wav-copy

    python3 ${BIN_DIR}/normalize.py \
        --metadata=dump/test/raw/metadata.jsonl \
        --dumpdir=dump/test/norm \
        --feats-stats=dump/train/feats_stats.npy \
        --phones-dict=dump/phone_id_map.txt \
        --speaker-dict=dump/speaker_id_map.txt \
        --add-blank=${add_blank} \
        --skip-wav-copy
fi