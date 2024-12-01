import argparse
import os
import time
import shutil

import torch
import torch.nn as nn
import torch.optim as optim
import torch.nn.functional as F
import torch.backends.cudnn as cudnn

    

import torchvision
import torchvision.transforms as transforms


class Utilities:
    @staticmethod
    def train(trainloader, model, criterion, optimizer, epoch, reg_alpha=None, print_freq = 100, device='cuda'):
        batch_time = AverageMeter()   ## at the begining of each epoch, this should be reset
        data_time = AverageMeter()
        losses = AverageMeter()
        top1 = AverageMeter()
    
        model.train()
    
        end = time.time()  # measure current time
        
        for i, (input, target) in enumerate(trainloader):
            # measure data loading time
            data_time.update(time.time() - end)  # data loading time
    
            input, target = input.to(device), target.to(device)
    
            # compute output
            output = model(input)
            loss = criterion(output, target)
            
            if reg_alpha:
                weight_loss = 0
                for layer in cus_loss_model.features:
                    if isinstance (layer, torch.nn.Conv2d):
                        weight_loss += layer.weight.abs().sum()
                        loss += reg_alpha * weight_loss
                        
            
    
            # measure accuracy and record loss
            prec = Utilities.accuracy(output, target)[0]
            losses.update(loss.item(), input.size(0))
            top1.update(prec.item(), input.size(0))
    
            # compute gradient and do SGD step
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
    
            # measure elapsed time
            batch_time.update(time.time() - end) # time spent to process one batch
            end = time.time()
            
      
    
            if i % print_freq == 0:
                print('Epoch: [{0}][{1}/{2}]\t'
                      'Time {batch_time.val:.3f} ({batch_time.avg:.3f})\t'
                      'Data {data_time.val:.3f} ({data_time.avg:.3f})\t'
                      'Loss {loss.val:.4f} ({loss.avg:.4f})\t'
                      'Prec {top1.val:.3f}% ({top1.avg:.3f}%)'.format(
                       epoch, i, len(trainloader), batch_time=batch_time,
                       data_time=data_time, loss=losses, top1=top1))
    @staticmethod
    def validate(val_loader, model, criterion, print_freq=100, device='cuda'):
        batch_time = AverageMeter()
        losses = AverageMeter()
        top1 = AverageMeter()
    
        # switch to evaluate mode
        model.eval()
        print("device = ", device)
    
        end = time.time()
        with torch.no_grad():
            for i, (input, target) in enumerate(val_loader):
             
                input, target = input.to(device), target.to(device)
    
                # compute output
                output = model(input)
                loss = criterion(output, target)
    
                # measure accuracy and record loss
                prec = Utilities.accuracy(output, target)[0]
                losses.update(loss.item(), input.size(0))
                top1.update(prec.item(), input.size(0))
    
                # measure elapsed time
                batch_time.update(time.time() - end)
                end = time.time()
    
                if i % print_freq == 0:  # This line shows how frequently print out the status. e.g., i%5 => every 5 batch, prints out
                    print('Test: [{0}/{1}]\t'
                      'Time {batch_time.val:.3f} ({batch_time.avg:.3f})\t'
                      'Loss {loss.val:.4f} ({loss.avg:.4f})\t'
                      'Prec {top1.val:.3f}% ({top1.avg:.3f}%)'.format(
                       i, len(val_loader), batch_time=batch_time, loss=losses,
                       top1=top1))
    
        print(' * Prec {top1.avg:.3f}% '.format(top1=top1))
        return top1.avg
    
    @staticmethod
    def accuracy(output, target, topk=(1,)):
        """Computes the precision@k for the specified values of k"""
        maxk = max(topk)
        batch_size = target.size(0)
    
        _, pred = output.topk(maxk, 1, True, True) # topk(k, dim=None, largest=True, sorted=True)
                                                   # will output (max value, its index)
        pred = pred.t()           # transpose
        correct = pred.eq(target.view(1, -1).expand_as(pred))   # "-1": calculate automatically
    
        res = []
        for k in topk:
            correct_k = correct[:k].view(-1).float().sum(0)  # view(-1): make a flattened 1D tensor
            res.append(correct_k.mul_(100.0 / batch_size))   # correct: size of [maxk, batch_size]
        return res
       
    @staticmethod      
    def save_checkpoint(state, is_best, fdir):
        filepath = os.path.join(fdir, 'checkpoint.pth')
        torch.save(state, filepath)
        if is_best:
            shutil.copyfile(filepath, os.path.join(fdir, 'model_best.pth.tar'))
    
    @staticmethod
    def adjust_learning_rate(optimizer, epoch):
        """For resnet, the lr starts from 0.1, and is divided by 10 at 80 and 120 epochs"""
        adjust_list = [150, 225]
        if epoch in adjust_list:
            for param_group in optimizer.param_groups:
                param_group['lr'] = param_group['lr'] * 0.1

    @staticmethod
    def train_model(model, model_name, optimizer, trainloader, criterion, epochs, testloader, pre_best_prec=0, reg_alpha=None):
        best_prec = pre_best_prec
        fdir = 'result/'+str(model_name)
        if not os.path.exists(fdir):
            os.makedirs(fdir)
        for epoch in range(0, epochs):
            Utilities.adjust_learning_rate(optimizer, epoch)
        
            Utilities.train(trainloader, model, criterion, optimizer, epoch, reg_alpha = reg_alpha)
            
            # evaluate on test set
            print("Validation starts")
            prec = Utilities.validate(testloader, model, criterion)
        
            # remember best precision and save checkpoint
            is_best = prec > best_prec
            best_prec = max(prec,best_prec)
            print('best acc: {:1f}'.format(best_prec))
            Utilities.save_checkpoint({
                'epoch': epoch + 1,
                'state_dict': model.state_dict(),
                'best_prec': best_prec,
                'optimizer': optimizer.state_dict(),
            }, is_best, fdir)

        return best_prec

    
    @staticmethod
    def test_model(model, model_name, testloader, device):
        fdir = 'result/'+str(model_name)+'/model_best.pth.tar'
        
        checkpoint = torch.load(fdir, map_location=torch.device(device))
        model.load_state_dict(checkpoint['state_dict'])
        
        
        criterion = nn.CrossEntropyLoss().to(device)
        
        model.eval()
        model.to(device)
        
        prec = Utilities.validate(testloader, model, criterion, device=device)

    @staticmethod
    def hook(a_layer, hook_type, save_output):
        hook_blocks = []
        for layer in a_layer:
            if isinstance(layer, hook_type):
                print("prehooked")
                hook_blocks.append(layer)
                layer.register_forward_pre_hook(save_output)       ## Input for the module will be grapped   
        return hook_blocks
####################################################





    
class AverageMeter(object):
    """Computes and stores the average and current value"""
    def __init__(self):
        self.reset()

    def reset(self):
        self.val = 0
        self.avg = 0
        self.sum = 0
        self.count = 0

    def update(self, val, n=1):
        self.val = val
        self.sum += val * n    ## n is impact factor
        self.count += n
        self.avg = self.sum / self.count
#model = nn.DataParallel(model).cuda()
#all_params = checkpoint['state_dict']
#model.load_state_dict(all_params, strict=False)
#criterion = nn.CrossEntropyLoss().cuda()
#(testloader, model, criterion)