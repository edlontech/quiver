Benchmark

Benchmark run from 2026-03-04 10:46:01.216279Z UTC

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
    <td style="white-space: nowrap; text-align: right">3359.66</td>
    <td style="white-space: nowrap; text-align: right">0.30 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;36.32%</td>
    <td style="white-space: nowrap; text-align: right">0.28 ms</td>
    <td style="white-space: nowrap; text-align: right">0.64 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap; text-align: right">2662.71</td>
    <td style="white-space: nowrap; text-align: right">0.38 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;31.96%</td>
    <td style="white-space: nowrap; text-align: right">0.36 ms</td>
    <td style="white-space: nowrap; text-align: right">0.74 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap; text-align: right">1327.30</td>
    <td style="white-space: nowrap; text-align: right">0.75 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;22.07%</td>
    <td style="white-space: nowrap; text-align: right">0.73 ms</td>
    <td style="white-space: nowrap; text-align: right">1.11 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap; text-align: right">998.85</td>
    <td style="white-space: nowrap; text-align: right">1.00 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;19.19%</td>
    <td style="white-space: nowrap; text-align: right">0.99 ms</td>
    <td style="white-space: nowrap; text-align: right">1.48 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap; text-align: right">688.88</td>
    <td style="white-space: nowrap; text-align: right">1.45 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;36.96%</td>
    <td style="white-space: nowrap; text-align: right">1.38 ms</td>
    <td style="white-space: nowrap; text-align: right">2.94 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap; text-align: right">245.29</td>
    <td style="white-space: nowrap; text-align: right">4.08 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.58%</td>
    <td style="white-space: nowrap; text-align: right">4.00 ms</td>
    <td style="white-space: nowrap; text-align: right">5.59 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap; text-align: right">80.28</td>
    <td style="white-space: nowrap; text-align: right">12.46 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;32.94%</td>
    <td style="white-space: nowrap; text-align: right">11.90 ms</td>
    <td style="white-space: nowrap; text-align: right">25.57 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap; text-align: right">41.68</td>
    <td style="white-space: nowrap; text-align: right">23.99 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;12.99%</td>
    <td style="white-space: nowrap; text-align: right">23.35 ms</td>
    <td style="white-space: nowrap; text-align: right">34.48 ms</td>
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
    <td style="white-space: nowrap;text-align: right">3359.66</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 10kb</td>
    <td style="white-space: nowrap; text-align: right">2662.71</td>
    <td style="white-space: nowrap; text-align: right">1.26x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1kb</td>
    <td style="white-space: nowrap; text-align: right">1327.30</td>
    <td style="white-space: nowrap; text-align: right">2.53x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 10kb</td>
    <td style="white-space: nowrap; text-align: right">998.85</td>
    <td style="white-space: nowrap; text-align: right">3.36x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 100kb</td>
    <td style="white-space: nowrap; text-align: right">688.88</td>
    <td style="white-space: nowrap; text-align: right">4.88x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 100kb</td>
    <td style="white-space: nowrap; text-align: right">245.29</td>
    <td style="white-space: nowrap; text-align: right">13.7x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 1mb</td>
    <td style="white-space: nowrap; text-align: right">80.28</td>
    <td style="white-space: nowrap; text-align: right">41.85x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 1mb</td>
    <td style="white-space: nowrap; text-align: right">41.68</td>
    <td style="white-space: nowrap; text-align: right">80.61x</td>
  </tr>

</table>