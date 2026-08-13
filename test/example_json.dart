// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

const exampleJson = '''{
  "layerA": {
    "data": [
      {
        "w": 600,
        "w1": 100
      },
      {
        "w": 700,
        "w1": 100
      }
    ]
  },

  "layerB": {
    "data": [
      {
        "d": 268,
        "d1": 100
      }
    ]
  },

  "layerC": {
    "data": [
      {
        "h": 800
      }
    ]
  },

  "layerD": {
    "data": [
      {
        "wMin": 0,
        "wMax": 900,
        "w1Min": 0,
        "w1Max": 900
      }
    ]
  },

  "layerE": {
    "data": [
      {
        "type": "XYZABC",
        "widths": "sLZpHAffgchgJnA++HqKtO",
        "depths": "k1IL2ctZHw4NpaA34w0d0I",
        "heights": "GBLHz0ayRkVUlms1wHDaJq",
        "ranges": "9rohAG49drWZs9tew4rDef"
      }
    ]
  },

  "layerF": {
    "data": [
      {
        "type": "XYZABC",
        "name": "Unterschrank 60cm"
      }
    ]
  },

  "layerG": {
    "data": [
      {
        "type": "XYZABC",
        "name": "Base Cabinet 23.5"
      }
    ]
  }
}
''';

const exampleJsonWithHashes = '''{
  "layerA": {
    "data": [
      {
        "w": 600,
        "w1": 100,
        "_hash": "ajRQhCx6QLPI8227B72r8I"
      },
      {
        "w": 700,
        "w1": 100,
        "_hash": "Jf177UAntzI4rIjKiU/MVt"
      }
    ],
    "_hash": "yqSa5ZxNeNTMnP5i6KWSmd"
  },
  "layerB": {
    "data": [
      {
        "d": 268,
        "d1": 100,
        "_hash": "9mJ7aZJexhfz8IfwF6bsuW"
      }
    ],
    "_hash": "tb0ffNF2ePpqsRxmvMDRrt"
  },
  "layerC": {
    "data": [
      {
        "h": 800,
        "_hash": "KvMHhk1dYYQ2o5Srt6pTUN"
      }
    ],
    "_hash": "Z4km/FzQoxyck+YHQDZMtV"
  },
  "layerD": {
    "data": [
      {
        "wMin": 0,
        "wMax": 900,
        "w1Min": 0,
        "w1Max": 900,
        "_hash": "6uw0BSIllrk6DuKyvQh+Rg"
      }
    ],
    "_hash": "rzLBCSXvxbmGujOhxGhrUm"
  },
  "layerE": {
    "data": [
      {
        "type": "XYZABC",
        "widths": "sLZpHAffgchgJnA++HqKtO",
        "depths": "k1IL2ctZHw4NpaA34w0d0I",
        "heights": "GBLHz0ayRkVUlms1wHDaJq",
        "ranges": "9rohAG49drWZs9tew4rDef",
        "_hash": "65LigWuYVGgifKnEZaOJET"
      }
    ],
    "_hash": "pDRglh2oWJcghTzzrzTLw6"
  },
  "layerF": {
    "data": [
      {
        "type": "XYZABC",
        "name": "Unterschrank 60cm",
        "_hash": "gjzETUIUf563ZJNHVEY9Wt"
      }
    ],
    "_hash": "r1u6gR8WLzPAZ3lEsAqREP"
  },
  "layerG": {
    "data": [
      {
        "type": "XYZABC",
        "name": "Base Cabinet 23.5",
        "_hash": "DEyuShUHDpWSJ7Rq/a3uz6"
      }
    ],
    "_hash": "RFZnY+Buvt2ECUnahPpIQ0"
  },
  "_hash": "D9Yt2C4/S4DemwBtAElAa2"
}''';
