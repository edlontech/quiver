Benchmark

Benchmark run from 2026-03-06 20:29:26.295426Z UTC

## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M4 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">12</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">24 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.19.1</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">28.1.1</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">10 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">20</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Devitation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 1kb</td>
    <td style="white-space: nowrap; text-align: right">3.64 K</td>
    <td style="white-space: nowrap; text-align: right">0.27 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;41.61%</td>
    <td style="white-space: nowrap; text-align: right">0.27 ms</td>
    <td style="white-space: nowrap; text-align: right">0.48 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap; text-align: right">2.93 K</td>
    <td style="white-space: nowrap; text-align: right">0.34 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.09%</td>
    <td style="white-space: nowrap; text-align: right">0.33 ms</td>
    <td style="white-space: nowrap; text-align: right">0.58 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap; text-align: right">1.83 K</td>
    <td style="white-space: nowrap; text-align: right">0.55 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;15.50%</td>
    <td style="white-space: nowrap; text-align: right">0.54 ms</td>
    <td style="white-space: nowrap; text-align: right">0.75 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap; text-align: right">1.65 K</td>
    <td style="white-space: nowrap; text-align: right">0.61 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;17.66%</td>
    <td style="white-space: nowrap; text-align: right">0.60 ms</td>
    <td style="white-space: nowrap; text-align: right">0.90 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap; text-align: right">0.79 K</td>
    <td style="white-space: nowrap; text-align: right">1.27 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.32%</td>
    <td style="white-space: nowrap; text-align: right">1.24 ms</td>
    <td style="white-space: nowrap; text-align: right">2.17 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap; text-align: right">0.46 K</td>
    <td style="white-space: nowrap; text-align: right">2.19 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.64%</td>
    <td style="white-space: nowrap; text-align: right">2.23 ms</td>
    <td style="white-space: nowrap; text-align: right">2.54 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap; text-align: right">0.0879 K</td>
    <td style="white-space: nowrap; text-align: right">11.38 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.91%</td>
    <td style="white-space: nowrap; text-align: right">11.08 ms</td>
    <td style="white-space: nowrap; text-align: right">19.65 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap; text-align: right">0.0542 K</td>
    <td style="white-space: nowrap; text-align: right">18.46 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;10.49%</td>
    <td style="white-space: nowrap; text-align: right">18.85 ms</td>
    <td style="white-space: nowrap; text-align: right">21.78 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1 1kb</td>
    <td style="white-space: nowrap;text-align: right">3.64 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap; text-align: right">2.93 K</td>
    <td style="white-space: nowrap; text-align: right">1.24x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap; text-align: right">1.83 K</td>
    <td style="white-space: nowrap; text-align: right">1.98x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap; text-align: right">1.65 K</td>
    <td style="white-space: nowrap; text-align: right">2.21x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap; text-align: right">0.79 K</td>
    <td style="white-space: nowrap; text-align: right">4.63x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap; text-align: right">0.46 K</td>
    <td style="white-space: nowrap; text-align: right">7.96x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap; text-align: right">0.0879 K</td>
    <td style="white-space: nowrap; text-align: right">41.41x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap; text-align: right">0.0542 K</td>
    <td style="white-space: nowrap; text-align: right">67.2x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">http1 1kb</td>
    <td style="white-space: nowrap">7.98 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap">8.85 KB</td>
    <td>1.11x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap">18.65 KB</td>
    <td>2.34x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap">0.73 KB</td>
    <td>0.09x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap">232.85 KB</td>
    <td>29.19x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.1x</td>
  </tr>
</table>



Reduction Count

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">http1 1kb</td>
    <td style="white-space: nowrap">817.42</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap">951.53</td>
    <td>1.16x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap">2348.88</td>
    <td>2.87x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap">25.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap">17582.47</td>
    <td>21.51x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap">32.00</td>
    <td>0.04x</td>
  </tr>
</table>