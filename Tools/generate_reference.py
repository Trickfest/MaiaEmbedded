#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Generate CPU/PyTorch reference fixtures; independently compare the ONNX export.

Requires the pinned upstream checkout, local checkpoint, and reference venv.
This does not download or execute untrusted checkpoint pickle code.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--upstream', type=Path, required=True)
p.add_argument('--checkpoint', type=Path, required=True)
p.add_argument('--onnx', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
revision = subprocess.check_output(['git', '-C', str(a.upstream), 'rev-parse', 'HEAD'], text=True).strip()
assert revision == '1e13597c42d4858b7cfd7cfdae01e297263364b2', 'Upstream revision mismatch'
assert not subprocess.check_output(['git', '-C', str(a.upstream), 'status', '--porcelain'], text=True).strip(), 'Upstream checkout is modified'
sys.path.insert(0, str(a.upstream.resolve()))
import chess
import numpy as np
import onnxruntime as ort
import torch
from maia3.uci import parse_args, load_model
from maia3.dataset import tokenize_board, get_historical_tokens
from maia3.utils import get_all_possible_moves, mirror_move

EXPECTED_CHECKPOINT = '3fc6181d5db789b45a15305732148757ae74efa3e0028e81ba335b462dac45c2'
EXPECTED_ONNX = '3454b03ae78baa64a87b345fdb1a457265d912caec531039b074f07eda0d8010'
for path, expected in [(a.checkpoint, EXPECTED_CHECKPOINT), (a.onnx, EXPECTED_ONNX)]:
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, f'Hash mismatch: {path}'

torch.set_num_threads(2)
cfg = parse_args(['--model', 'maia3-79m', '--device', 'cpu', '--no-use-amp'])
cfg.checkpoint_path = str(a.checkpoint)
model = load_model(cfg)
options = ort.SessionOptions()
options.intra_op_num_threads = 2
options.inter_op_num_threads = 1
options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC
session = ort.InferenceSession(str(a.onnx), sess_options=options, providers=['CPUExecutionProvider'])
vocabulary = {m: i for i, m in enumerate(get_all_possible_moves())}
cases = []
def add(name, fen=chess.STARTING_FEN, moves=(), history=False, self_elo=1600, opponent_elo=1600):
    cases.append((name, fen, list(moves), history, self_elo, opponent_elo))
add('start-600', self_elo=600)
add('start-2600', self_elo=2600, opponent_elo=2400)
add('black-after-e4', moves=['e2e4'])
add('black-after-d4', moves=['d2d4'], self_elo=1000, opponent_elo=2200)
ruy = 'e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7'.split()
add('ruy-current', moves=ruy)
add('ruy-history', moves=ruy, history=True)
add('short-history', moves=['e2e4','c7c5','g1f3'], history=True)
add('sicilian', moves='e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4'.split(), history=True)
castle = 'r3k2r/ppp2ppp/2n5/3pp3/3PP3/2N5/PPP2PPP/R3K2R'
add('castling-white', fen=castle+' w KQkq - 0 8')
add('castling-black', fen=castle+' b KQkq - 0 8')
add('en-passant-white', fen='4k3/8/8/3pP3/8/8/8/4K2R w K d6 0 20')
add('en-passant-black', fen='4k2r/8/8/8/3Pp3/8/8/4K3 b k d3 0 20')
add('promotion-white', fen='4k3/P7/8/8/8/8/8/4K3 w - - 0 1')
add('promotion-black', fen='4k3/8/8/8/8/8/p7/4K3 b - - 0 1')
add('promotion-capture', fen='1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1')
add('rook-endgame', fen='8/4k3/8/3p4/3P4/4K3/8/R6r w - - 0 40', self_elo=1200, opponent_elo=2000)
add('in-check', moves='e2e4 e7e5 d1h5 b8c6 h5f7'.split(), self_elo=1400)
add('checkmate', fen='7k/6Q1/5K2/8/8/8/8/8 b - - 0 1')
add('stalemate', fen='7k/5K2/6Q1/8/8/8/8/8 b - - 0 1')
add('insufficient-material', fen='4k3/8/8/8/8/8/8/4K3 w - - 0 1')
fixtures=[]
max_error=0.0
for name, fen, moves, use_history, self_elo, opponent_elo in cases:
    board=chess.Board(fen)
    assert board.is_valid(), (name, board.status())
    boards=[board.copy()]
    for move in moves:
        board.push_uci(move)
        boards.append(board.copy())
    window=boards[-8:] if use_history else [board]
    tokens=get_historical_tokens([tokenize_board(b) for b in window], cfg, 0,0,0,0).unsqueeze(0)
    item=dict(id=name, initialFEN=fen, moves=moves, useHistory=use_history,
              selfRating=self_elo, opponentRating=opponent_elo,
              tokenSHA256=hashlib.sha256(tokens.numpy().astype('<f4').tobytes()).hexdigest(),
              terminal=board.is_game_over(), legalMoves=sorted(m.uci() for m in board.legal_moves),
              logits={}, probabilities={}, valueLogits=[])
    if not item['terminal']:
        sr=torch.tensor([self_elo], dtype=torch.int64)
        opp=torch.tensor([opponent_elo], dtype=torch.int64)
        with torch.inference_mode():
            expected=model(tokens,sr,opp)
        actual=session.run(None, dict(tokens=tokens.numpy(),self_elo=sr.numpy(),opponent_elo=opp.numpy()))
        errors=[float(np.max(np.abs(x.numpy()-y))) for x,y in zip(expected,actual)]
        max_error=max(max_error,*errors)
        assert max(errors)<1e-4, (name, errors)
        logits=expected[0].reshape(-1)
        indices=[vocabulary[m if board.turn else mirror_move(m)] for m in item['legalMoves']]
        probs=torch.softmax(logits[indices], dim=0).tolist()
        item['logits']={m: float(logits[i]) for m,i in zip(item['legalMoves'],indices)}
        item['probabilities']=dict(zip(item['legalMoves'], probs))
        item['valueLogits']=expected[1].reshape(-1).tolist()
    fixtures.append(item)
result=dict(schemaVersion=1, upstreamRevision='1e13597c42d4858b7cfd7cfdae01e297263364b2',
 modelSHA256=EXPECTED_ONNX, checkpointSHA256=EXPECTED_CHECKPOINT,
 torchVersion=torch.__version__, onnxRuntimeVersion=ort.__version__,
 logitTolerance=1e-4, probabilityTolerance=1e-5, maxPythonONNXError=max_error, cases=fixtures)
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(f'{len(fixtures)} fixtures; max PyTorch/ONNX error {max_error:.9g}; {a.output}')
