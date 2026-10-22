#!/usr/bin/env python3
"""
Rebuild handbake/assets from the original repository (only needed if the
bundled weights are missing or you want to verify them).

    git clone https://github.com/sjvasquez/handwriting-synthesis
    pip install tensorflow-cpu        # only for this one-off conversion
    python tools/convert_checkpoint.py handwriting-synthesis

Reads checkpoints/model-17900 with TensorFlow's checkpoint reader, keeps the
10 model tensors as float32 in a compressed .npz, and copies the style
priming files.
"""
import argparse
import shutil
from pathlib import Path

import numpy as np

KEEP = [
    'rnn/LSTMAttentionCell/attention/biases',
    'rnn/LSTMAttentionCell/attention/weights',
    'rnn/LSTMAttentionCell/lstm_cell/bias',
    'rnn/LSTMAttentionCell/lstm_cell/kernel',
    'rnn/LSTMAttentionCell/lstm_cell_1/bias',
    'rnn/LSTMAttentionCell/lstm_cell_1/kernel',
    'rnn/LSTMAttentionCell/lstm_cell_2/bias',
    'rnn/LSTMAttentionCell/lstm_cell_2/kernel',
    'rnn/gmm/biases',
    'rnn/gmm/weights',
]


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('repo', type=Path, help='path to a clone of sjvasquez/handwriting-synthesis')
    p.add_argument('--out', type=Path, default=Path(__file__).resolve().parent.parent / 'handbake' / 'assets')
    a = p.parse_args()

    import tensorflow as tf  # noqa: imported late so --help works without it

    reader = tf.train.load_checkpoint(str(a.repo / 'checkpoints' / 'model-17900'))
    tensors = {k.replace('/', '__'): reader.get_tensor(k).astype(np.float32) for k in KEEP}
    a.out.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(a.out / 'weights.npz', **tensors)
    styles = a.out / 'styles'
    styles.mkdir(exist_ok=True)
    for f in sorted((a.repo / 'styles').glob('style-*-*.npy')):
        shutil.copy2(f, styles / f.name)
    print(f'wrote {a.out / "weights.npz"} and {len(list(styles.glob("*.npy")))} style files')


if __name__ == '__main__':
    main()
