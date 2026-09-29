/// Stable server/engine codes, localized only in the client.
List<String> skillFeedbackLabels(Object? codes) => codes is Iterable
    ? [
        for (final code in codes)
          if (code == 'focused')
            'Concentração +25%'
          else if (code == 'fragmented')
            'Fragmentação · 2 golpes'
          else if (code == 'seal_100')
            'Selo perfeito · 100% dano'
          else if (code == 'seal_80')
            'Quase perfeito · 80% dano'
          else if (code == 'seal_60')
            'Selo estável · 60% dano'
          else if (code == 'seal_40')
            'Selo instável · 40% dano',
      ]
    : const [];
