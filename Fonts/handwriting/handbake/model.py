"""
Handwriting model: NumPy port of the sampling path of
sjvasquez/handwriting-synthesis (Graves 2013: 3-layer LSTM with a soft
attention window over the text and a 20-component mixture density output).

The pretrained TensorFlow 1.x checkpoint was converted once to
assets/weights.npz (see tools/convert_checkpoint.py), so no TensorFlow is
needed at runtime.

The model emits pen offsets [dx, dy, end_of_stroke], one per time step.
Steps are evenly spaced in time, so the distance between points is pen speed.
"""
import os
import unicodedata
from pathlib import Path

import numpy as np

ASSETS = Path(__file__).resolve().parent / 'assets'
DEFAULT_WEIGHTS = Path(os.environ.get('HANDBAKE_WEIGHTS', ASSETS / 'weights.npz'))
DEFAULT_STYLES = Path(os.environ.get('HANDBAKE_STYLES', ASSETS / 'styles'))

# Character set the model was trained on (index 0 is the end-of-text token).
# Note: no capital Q, X or Z, no accented letters, few symbols.
ALPHABET = [
    '\x00', ' ', '!', '"', '#', "'", '(', ')', ',', '-', '.',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ':', ';',
    '?', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
    'L', 'M', 'N', 'O', 'P', 'R', 'S', 'T', 'U', 'V', 'W', 'Y',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l',
    'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
    'y', 'z'
]
SUPPORTED = set(ALPHABET[1:])
_A2N = {c: i for i, c in enumerate(ALPHABET)}
STYLES = list(range(13))  # priming samples shipped in assets/styles
MAX_CHARS = 75            # limit of the original implementation

_V, _H, _K_ATT, _K_OUT = len(ALPHABET), 400, 10, 20

_FALLBACK = {
    'Q': 'q', 'X': 'x', 'Z': 'z',
    'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'Ä': 'Ae', 'Ö': 'Oe', 'Ü': 'Ue', 'ß': 'ss',
    '‘': "'", '’': "'", '“': '"', '”': '"',
    '–': '-', '—': '-', '…': '...', ' ': ' ',
}


def unsupported_chars(text):
    return sorted({c for c in text if c not in SUPPORTED})


def normalize_text(text, fallback=False):
    """Validate text against the model's alphabet.

    fallback=True rewrites what it can: Q/X/Z -> lowercase, umlauts -> ae/oe/ue,
    other accents stripped, typographic quotes/dashes -> ASCII.
    Raises ValueError listing any characters that remain unsupported.
    """
    if fallback:
        text = ''.join(_FALLBACK.get(c, c) for c in text)
        text = ''.join(
            c if c in SUPPORTED else
            ''.join(ch for ch in unicodedata.normalize('NFKD', c) if not unicodedata.combining(ch))
            for c in text
        )
    if not text.strip():
        raise ValueError('text is empty')
    if len(text) > MAX_CHARS:
        raise ValueError(f'text is {len(text)} characters; split it into lines of at most {MAX_CHARS}')
    bad = unsupported_chars(text)
    if bad:
        raise ValueError(f'unsupported characters {bad!r} in {text!r} (try fallback=True / --fallback)')
    return text


def _sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))


def _softplus(x):
    return np.logaddexp(0.0, x)


class HandwritingModel:
    def __init__(self, weights=DEFAULT_WEIGHTS, styles_dir=DEFAULT_STYLES):
        w = np.load(weights)
        p = 'rnn__LSTMAttentionCell__'
        self.k1, self.b1 = w[p + 'lstm_cell__kernel'], w[p + 'lstm_cell__bias']
        self.k2, self.b2 = w[p + 'lstm_cell_1__kernel'], w[p + 'lstm_cell_1__bias']
        self.k3, self.b3 = w[p + 'lstm_cell_2__kernel'], w[p + 'lstm_cell_2__bias']
        self.ka, self.ba = w[p + 'attention__weights'], w[p + 'attention__biases']
        self.kg, self.bg = w['rnn__gmm__weights'], w['rnn__gmm__biases']
        self.styles_dir = Path(styles_dir)

    # --- one LSTM cell (tf.contrib.rnn.LSTMCell: gates i, j, f, o; forget bias 1.0)
    @staticmethod
    def _lstm(x, h, c, k, b):
        z = np.concatenate([x, h]) @ k + b
        i, j, f, o = np.split(z, 4)
        c = _sigmoid(f + 1.0) * c + _sigmoid(i) * np.tanh(j)
        return _sigmoid(o) * np.tanh(c), c

    def _step(self, x, s, onehot):
        h1, c1 = self._lstm(np.concatenate([s['w'], x]), s['h1'], s['c1'], self.k1, self.b1)
        att = _softplus(np.concatenate([s['w'], x, h1]) @ self.ka + self.ba)
        alpha, beta, kappa = np.split(att, 3)
        kappa = s['kappa'] + kappa / 25.0
        beta = np.clip(beta, 0.01, np.inf)
        u = np.arange(onehot.shape[0])[None, :]
        phi = np.sum(alpha[:, None] * np.exp(-np.square(kappa[:, None] - u) / beta[:, None]), axis=0)
        w = phi @ onehot
        h2, c2 = self._lstm(np.concatenate([x, h1, w]), s['h2'], s['c2'], self.k2, self.b2)
        h3, c3 = self._lstm(np.concatenate([x, h2, w]), s['h3'], s['c3'], self.k3, self.b3)
        return dict(h1=h1, c1=c1, h2=h2, c2=c2, h3=h3, c3=c3, kappa=kappa, w=w, phi=phi)

    def _mdn(self, s, bias):
        z = s['h3'] @ self.kg + self.bg
        pis, sig, rho, mu, e = np.split(z, np.cumsum([_K_OUT, 2 * _K_OUT, _K_OUT, 2 * _K_OUT]))
        pis = pis * (1 + bias)
        sig = sig - bias
        pis = np.exp(pis - pis.max())
        pis /= pis.sum()
        pis = np.where(pis < .01, 0.0, pis)
        pis /= pis.sum()
        sig = np.clip(np.exp(sig), 1e-4, np.inf)
        rho = np.clip(np.tanh(rho), 1e-8 - 1, 1 - 1e-8)
        e = float(np.clip(_sigmoid(e[0]), 1e-8, 1 - 1e-8))
        e = 0.0 if e < .01 else e
        return pis, mu[:_K_OUT], mu[_K_OUT:], sig[:_K_OUT], sig[_K_OUT:], rho, e

    @staticmethod
    def _sample_out(params, rng):
        pis, mu1, mu2, s1, s2, rho, e = params
        k = rng.choice(_K_OUT, p=pis)
        cov = np.array([[s1[k] ** 2, rho[k] * s1[k] * s2[k]],
                        [rho[k] * s1[k] * s2[k], s2[k] ** 2]])
        xy = rng.multivariate_normal([mu1[k], mu2[k]], cov)
        return np.array([xy[0], xy[1], float(rng.random() < e)])

    def sample(self, text, style=12, bias=0.75, seed=1):
        """Generate pen offsets for one line of text.

        style: 0-12 primes the model with a real writer's sample; None = unprimed.
        bias:  higher = neater/more regular (0 = raw model, ~0.5-1.0 typical).
        seed:  same (text, style, bias, seed) -> same take on the same machine.
        """
        text = normalize_text(text)
        rng = np.random.default_rng(seed)
        if style is not None:
            prime = np.load(self.styles_dir / f'style-{style}-strokes.npy')
            prime_text = np.load(self.styles_dir / f'style-{style}-chars.npy').tobytes().decode('utf-8')
            full = prime_text + ' ' + text
        else:
            prime, full = None, text
        chars = np.array([_A2N[c] for c in full] + [0])
        n = len(chars)
        # padded, masked char buffer (like the original) so attention can run past the end
        onehot = np.zeros((n + 20, _V))
        onehot[np.arange(n), chars] = 1.0
        z = np.zeros(_H)
        s = dict(h1=z, c1=z, h2=z, c2=z, h3=z, c3=z,
                 kappa=np.zeros(_K_ATT), w=np.zeros(_V), phi=np.zeros(n + 20))

        if prime is not None:
            for x in prime:
                s = self._step(x.astype(np.float64), s, onehot)
            x = self._sample_out(self._mdn(s, bias), rng)
        else:
            x = np.array([0.0, 0.0, 1.0])

        out = [x]
        for _ in range(40 * len(text)):
            s = self._step(x, s, onehot)
            params = self._mdn(s, bias)
            # stop once attention has reached the last char and the pen lifts
            # (the random draw happens every step so seeds stay reproducible)
            idx = int(np.argmax(s['phi']))
            pen_up = rng.random() < params[-1]
            if (idx >= n - 1 and pen_up) or idx >= n:
                break
            x = self._sample_out(params, rng)
            out.append(x)
        return np.array(out)
