"""ECGFounder Net1D architecture, adapted from the official PKUDigitalHealth implementation.
Source: https://github.com/PKUDigitalHealth/ECGFounder/blob/master/net1d.py
MIT license; see LICENSE_ECGFOUNDER.txt.
"""
import torch
import torch.nn as nn
import torch.nn.functional as F

class MyConv1dPadSame(nn.Module):
    def __init__(self, in_channels, out_channels, kernel_size, stride, groups=1):
        super().__init__(); self.kernel_size=kernel_size; self.stride=stride
        self.conv=nn.Conv1d(in_channels,out_channels,kernel_size,stride=stride,groups=groups)
    def forward(self,x):
        n=x.shape[-1]; out=(n+self.stride-1)//self.stride
        p=max(0,(out-1)*self.stride+self.kernel_size-n)
        x=F.pad(x,(p//2,p-p//2),"constant",0)
        return self.conv(x)

class MyMaxPool1dPadSame(nn.Module):
    def __init__(self,kernel_size):
        super().__init__(); self.kernel_size=kernel_size; self.pool=nn.MaxPool1d(kernel_size)
    def forward(self,x):
        p=max(0,self.kernel_size-1)
        return self.pool(F.pad(x,(p//2,p-p//2),"constant",0))

class Swish(nn.Module):
    def forward(self,x): return x*torch.sigmoid(x)

class BasicBlock(nn.Module):
    def __init__(self,in_channels,out_channels,ratio,kernel_size,stride,groups,downsample,is_first_block=False,use_bn=False,use_do=False):
        super().__init__(); self.in_channels=in_channels; self.out_channels=out_channels
        self.downsample=downsample; self.stride=stride if downsample else 1
        self.is_first_block=is_first_block; self.use_bn=use_bn; self.use_do=use_do
        mid=int(out_channels*ratio)
        self.bn1=nn.BatchNorm1d(in_channels); self.activation1=Swish(); self.do1=nn.Dropout(.5)
        self.conv1=MyConv1dPadSame(in_channels,mid,1,1)
        self.bn2=nn.BatchNorm1d(mid); self.activation2=Swish(); self.do2=nn.Dropout(.5)
        self.conv2=MyConv1dPadSame(mid,mid,kernel_size,self.stride,groups)
        self.bn3=nn.BatchNorm1d(mid); self.activation3=Swish(); self.do3=nn.Dropout(.5)
        self.conv3=MyConv1dPadSame(mid,out_channels,1,1)
        self.se_fc1=nn.Linear(out_channels,out_channels//2); self.se_fc2=nn.Linear(out_channels//2,out_channels)
        self.se_activation=Swish()
        if downsample: self.max_pool=MyMaxPool1dPadSame(self.stride)
    def forward(self,x):
        identity=x; out=x
        if not self.is_first_block:
            if self.use_bn: out=self.bn1(out)
            out=self.activation1(out)
            if self.use_do: out=self.do1(out)
        out=self.conv1(out)
        if self.use_bn: out=self.bn2(out)
        out=self.activation2(out)
        if self.use_do: out=self.do2(out)
        out=self.conv2(out)
        if self.use_bn: out=self.bn3(out)
        out=self.activation3(out)
        if self.use_do: out=self.do3(out)
        out=self.conv3(out)
        se=out.mean(-1); se=self.se_fc1(se); se=self.se_activation(se); se=self.se_fc2(se); se=torch.sigmoid(se)
        out=torch.einsum('abc,ab->abc',out,se)
        if self.downsample: identity=self.max_pool(identity)
        if self.out_channels != self.in_channels:
            identity=identity.transpose(-1,-2)
            a=(self.out_channels-self.in_channels)//2; b=self.out_channels-self.in_channels-a
            identity=F.pad(identity,(a,b),"constant",0).transpose(-1,-2)
        return out+identity

class BasicStage(nn.Module):
    def __init__(self,in_channels,out_channels,ratio,kernel_size,stride,groups,i_stage,m_blocks,use_bn=False,use_do=False):
        super().__init__(); self.block_list=nn.ModuleList()
        for i in range(m_blocks):
            first=(i_stage==0 and i==0); down=(i==0)
            self.block_list.append(BasicBlock(in_channels if down else out_channels,out_channels,ratio,kernel_size,stride,groups,down,first,use_bn,use_do))
    def forward(self,x):
        for block in self.block_list: x=block(x)
        return x

class Net1D(nn.Module):
    def __init__(self,in_channels=12,base_filters=64,ratio=1,filter_list=None,m_blocks_list=None,kernel_size=16,stride=2,groups_width=16,n_classes=5,use_bn=False,use_do=False,return_features=False,verbose=False):
        super().__init__()
        filter_list=filter_list or [64,160,160,400,400,1024,1024]
        m_blocks_list=m_blocks_list or [2,2,2,3,3,4,4]
        self.use_bn=use_bn; self.return_features=return_features
        self.first_conv=MyConv1dPadSame(in_channels,base_filters,kernel_size,2)
        self.first_bn=nn.BatchNorm1d(base_filters); self.first_activation=Swish()
        self.stage_list=nn.ModuleList(); ch=base_filters
        for i,(out_ch,n_blocks) in enumerate(zip(filter_list,m_blocks_list)):
            self.stage_list.append(BasicStage(ch,out_ch,ratio,kernel_size,stride,out_ch//groups_width,i,n_blocks,use_bn,use_do))
            ch=out_ch
        self.dense=nn.Linear(ch,n_classes)
    def forward(self,x):
        x=self.first_conv(x)
        if self.use_bn: x=self.first_bn(x)
        x=self.first_activation(x)
        for stage in self.stage_list: x=stage(x)
        features=x.mean(-1); logits=self.dense(features)
        return (logits,features) if self.return_features else logits
