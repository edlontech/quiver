Benchmark

Benchmark run from 2026-03-06 20:31:35.461892Z UTC

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
    <td style="white-space: nowrap">10</td>
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
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap; text-align: right">7.29 K</td>
    <td style="white-space: nowrap; text-align: right">137.16 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;19.36%</td>
    <td style="white-space: nowrap; text-align: right">135.00 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">206.09 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap; text-align: right">6.38 K</td>
    <td style="white-space: nowrap; text-align: right">156.63 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;18.30%</td>
    <td style="white-space: nowrap; text-align: right">154.46 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">233.25 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">3.29 K</td>
    <td style="white-space: nowrap; text-align: right">304.00 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.76%</td>
    <td style="white-space: nowrap; text-align: right">297.38 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">486.50 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">3.08 K</td>
    <td style="white-space: nowrap; text-align: right">324.29 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;19.97%</td>
    <td style="white-space: nowrap; text-align: right">318.46 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">497.63 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap;text-align: right">7.29 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap; text-align: right">6.38 K</td>
    <td style="white-space: nowrap; text-align: right">1.14x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">3.29 K</td>
    <td style="white-space: nowrap; text-align: right">2.22x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">3.08 K</td>
    <td style="white-space: nowrap; text-align: right">2.36x</td>
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
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap">7.98 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap">2.14 KB</td>
    <td>0.27x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap">0.76 KB</td>
    <td>0.1x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap">1.29 KB</td>
    <td>0.16x</td>
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
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap">818.68</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap">114.00</td>
    <td>0.14x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap">26.00</td>
    <td>0.03x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap">73.76</td>
    <td>0.09x</td>
  </tr>
</table>